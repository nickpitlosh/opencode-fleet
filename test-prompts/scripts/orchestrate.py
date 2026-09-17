#!/usr/bin/env python3
"""
orchestrate.py — Master test orchestrator for the agent evaluation gauntlet.

Executes all 28 agents × 16 domains (448 test runs) through the FIFO daemon
system with:
  - Max 4 concurrent tests
  - Staggered launches (500ms between each)
  - Per-test timeout (default 120s)
  - Resumable state (skips completed tests)
  - Progress tracking with ETA
  - Structured JSON output

Usage:
  python3 orchestrate.py [--max-concurrent 4] [--timeout 120] [--agents a,b,c] [--domains x,y,z]
"""

import json
import os
import subprocess
import sys
import time
import hashlib
import signal
import threading
from pathlib import Path
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict

# ── Configuration ──────────────────────────────────────────────────────────

FIFO_BASE = Path.home() / ".agent-fifo"
PROMPT_DIR = Path(os.environ.get("PROMPT_DIR", str(Path.home() / "test-prompts/prompts")))
RESULTS_DIR = Path.home() / "test-prompts/results"
STATE_FILE = RESULTS_DIR / "orchestrate_state.json"
MAX_CONCURRENT = int(os.environ.get("MAX_CONCURRENT", 4))
STAGGER_DELAY = float(os.environ.get("STAGGER_MS", 500)) / 1000.0
PER_TEST_TIMEOUT = int(os.environ.get("TEST_TIMEOUT", 120))

# ── Logging ─────────────────────────────────────────────────────────────────

def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {level}: {msg}", flush=True)

# ── State Management ────────────────────────────────────────────────────────

class State:
    """Persistent state for resumable test execution."""

    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()
        self.data = {"completed": {}, "failed": {}, "stats": {"start": None, "end": None}}
        self._load()

    def _load(self):
        if self.path.exists():
            try:
                self.data = json.loads(self.path.read_text())
            except Exception:
                pass

    def save(self):
        with self.lock:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(self.data, indent=2))

    def is_completed(self, agent, domain):
        return f"{agent}/{domain}" in self.data["completed"]

    def mark_completed(self, agent, domain, result):
        with self.lock:
            self.data["completed"][f"{agent}/{domain}"] = result
            self.data["stats"]["last_update"] = datetime.now().isoformat()
        self.save()

    def mark_failed(self, agent, domain, error):
        with self.lock:
            self.data["failed"][f"{agent}/{domain}"] = error
        self.save()

    @property
    def completed_count(self):
        return len(self.data["completed"])

    @property
    def failed_count(self):
        return len(self.data["failed"])


# ── Task Execution ─────────────────────────────────────────────────────────

def send_prompt_fifo(agent, prompt, timeout=10):
    """Write prompt to agent's FIFO with timeout.

    Uses subprocess.run with explicit stdout redirection to ensure EOF
    is properly signaled to the daemon. Direct file writes and os.system
    approaches fail to wake up the blocking FIFO reader.
    """
    fifo_in = FIFO_BASE / agent / "in"
    if not fifo_in.exists():
        raise RuntimeError(f"FIFO not found: {fifo_in}")

    try:
        with open(fifo_in, 'w') as fifo_f:
            subprocess.run(
                ["echo", prompt],
                stdout=fifo_f,
                timeout=timeout,
                check=True,
                stderr=subprocess.DEVNULL
            )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"FIFO write timed out for {agent}")


def is_daemon_running(agent):
    """Check if the agent's FIFO daemon is alive. Returns True/False."""
    pidfile = FIFO_BASE / agent / "daemon.pid"
    if not pidfile.exists():
        return False
    pid = pidfile.read_text().strip()
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
        return True
    except (ProcessLookupError, PermissionError, OSError):
        return False


def get_response(agent, task_id=None, max_wait=120):
    """Wait for a task to complete and extract its output from the log."""
    log_path = FIFO_BASE / agent / "log"
    deadline = time.time() + max_wait

    # Record initial line count
    initial_lines = 0
    if log_path.exists():
        initial_lines = len(log_path.read_text().splitlines())

    while time.time() < deadline:
        if not log_path.exists():
            time.sleep(0.5)
            continue

        lines = log_path.read_text().splitlines()
        # Look for TASK END after our initial count (log format: "==== TASK END ...")
        recent = lines[initial_lines:]
        for i, line in enumerate(recent):
            if "TASK END" in line:
                # Found a completed task, extract output
                task_start = None
                for j in range(i - 1, -1, -1):
                    if "TASK START" in recent[j]:
                        task_start = j
                        break
                if task_start is not None:
                    # Extract output between markers (skip TASK START line and PROMPT line)
                    output_lines = recent[task_start + 2:i]
                    # Filter: remove ANSI, "---- output ----", "> build" lines
                    import re
                    cleaned = []
                    for ol in output_lines:
                        if "---- output ----" in ol or ol.startswith("> build"):
                            continue
                        # Strip ANSI
                        ol = re.sub(r'\x1b\[[0-9;]*m', '', ol)
                        if ol.strip():
                            cleaned.append(ol.strip())
                    return "\n".join(cleaned), True

        time.sleep(1)

    return "TIMEOUT: no response within {}s".format(max_wait), False


def ensure_daemon(agent, model):
    """Ensure the daemon is running for an agent."""
    if is_daemon_running(agent):
        return True

    daemon_script = FIFO_BASE / "agent-daemon.sh"
    if not daemon_script.exists():
        raise RuntimeError(f"Daemon script not found: {daemon_script}")

    # Start via root to avoid shell blocking
    try:
        subprocess.run(
            ["bash", "-c", f"echo '16834d' | su -c 'setsid nohup bash {daemon_script} {agent} {model} </dev/null >>{FIFO_BASE}/{agent}/launch.log 2>&1 &' root"],
            timeout=10, check=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

    # Wait for daemon to come up
    for _ in range(30):
        if is_daemon_running(agent):
            return True
        time.sleep(0.3)
    return False


def run_single_test(agent, domain, prompt, timeout=120):
    """Execute a single agent×domain test. Returns result dict."""
    start_time = time.time()

    try:
        # Verify daemon is running (do NOT try to start it - use agent-ctl.sh for that)
        if not is_daemon_running(agent):
            return {
                "agent": agent, "domain": domain,
                "status": "error", "error": "daemon not running",
                "duration_s": time.time() - start_time
            }

        # Send prompt
        send_prompt_fifo(agent, prompt)

        # Wait for response
        response, success = get_response(agent, max_wait=timeout)

        duration = time.time() - start_time

        return {
            "agent": agent, "domain": domain,
            "status": "ok" if success else "timeout",
            "response": response,
            "duration_s": round(duration, 2),
            "timestamp": datetime.now().isoformat()
        }

    except Exception as e:
        return {
            "agent": agent, "domain": domain,
            "status": "error", "error": str(e),
            "duration_s": round(time.time() - start_time, 2)
        }


# ── Main Orchestrator ───────────────────────────────────────────────────────

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Agent test orchestrator")
    parser.add_argument("--max-concurrent", type=int, default=MAX_CONCURRENT)
    parser.add_argument("--timeout", type=int, default=PER_TEST_TIMEOUT)
    parser.add_argument("--agents", type=str, help="Comma-separated agent list")
    parser.add_argument("--domains", type=str, help="Comma-separated domain list")
    parser.add_argument("--stagger", type=float, default=STAGGER_DELAY)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # Determine agent/domain lists
    agent_bin = Path.home() / ".config/opencode/agent-bin"
    all_agents = sorted(agent_bin.iterdir())
    all_agents = [a.name for a in all_agents if a.is_file() and not a.name.startswith(".")]

    if args.agents:
        agents = [a.strip() for a in args.agents.split(",") if a.strip() in all_agents]
    else:
        agents = all_agents

    if args.domains:
        domains = [d.strip() for d in args.domains.split(",") if (PROMPT_DIR / f"{d.strip()}.md").exists()]
    else:
        domains = [p.stem for p in sorted(PROMPT_DIR.glob("*.md"))]

    # Build task list (skip already completed)
    state = State(STATE_FILE)
    state.data["stats"]["start"] = datetime.now().isoformat()
    state.save()

    tasks = []
    for domain in domains:
        prompt_file = PROMPT_DIR / f"{domain}.md"
        prompt = prompt_file.read_text() if prompt_file.exists() else ""
        for agent in agents:
            if not state.is_completed(agent, domain):
                tasks.append((agent, domain, prompt))

    total = len(agents) * len(domains)
    already_done = state.completed_count
    log(f"Agents: {len(agents)}, Domains: {len(domains)}, Total: {total}")
    log(f"Already completed: {already_done}, Remaining: {len(tasks)}")
    log(f"Max concurrent: {args.max_concurrent}, Stagger: {args.stagger}s, Timeout: {args.timeout}s")

    if args.dry_run:
        for agent, domain, _ in tasks:
            log(f"  {agent}/{domain}")
        return

    if not tasks:
        log("All tests already complete. Use --reset to re-run.")
        return

    # Execute with controlled concurrency.
    # Each agent gets its own daemon, so we can run up to max_concurrent
    # tests on DIFFERENT agents simultaneously. Same-agent tests are
    # serialized by the daemon FIFO (one task at a time per agent).
    results = []
    start_time = time.time()
    completed = 0
    failed = 0
    agent_locks = defaultdict(threading.Lock)  # One lock per agent

    def execute_task(task_info):
        agent, domain, prompt = task_info
        time.sleep(args.stagger)  # Stagger launches
        # Lock per agent to prevent same-agent concurrent access
        with agent_locks[agent]:
            result = run_single_test(agent, domain, prompt, args.timeout)
        return result

    with ThreadPoolExecutor(max_workers=args.max_concurrent) as executor:
        futures = {executor.submit(execute_task, t): t for t in tasks}

        for future in as_completed(futures):
            agent, domain, _ = futures[future]
            try:
                result = future.result()
            except Exception as e:
                result = {"agent": agent, "domain": domain, "status": "error", "error": str(e)}

            if result["status"] == "ok":
                state.mark_completed(agent, domain, result)
                completed += 1
            else:
                state.mark_failed(agent, domain, result.get("error", "unknown"))
                failed += 1

            # Progress
            elapsed = time.time() - start_time
            done = completed + failed
            pct = done / len(tasks) * 100
            rate = done / elapsed if elapsed > 0 else 0
            eta = (len(tasks) - done) / rate if rate > 0 else 0

            status_char = "OK" if result["status"] == "ok" else "FAIL"
            log(f"[{done}/{len(tasks)}] {pct:.0f}% {status_char} {agent}/{domain} ({result.get('duration_s', 0):.1f}s) ETA: {timedelta(seconds=int(eta))}")

            results.append(result)

    # Final stats
    total_time = time.time() - start_time
    state.data["stats"]["end"] = datetime.now().isoformat()
    state.data["stats"]["total_time_s"] = round(total_time, 2)
    state.data["stats"]["completed"] = completed
    state.data["stats"]["failed"] = failed
    state.save()

    log(f"Complete: {completed} ok, {failed} failed, {total_time:.1f}s total")
    log(f"State saved to {STATE_FILE}")
    log(f"Next: python3 evaluate.py && python3 report_gen.py")

if __name__ == "__main__":
    main()
