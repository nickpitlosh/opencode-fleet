#!/usr/bin/env bash
# test-prompts/scripts/deploy-report.sh — Deploy the evaluation report to communityservices.cc.
#
# Places the report in wwwroot/reports/agent-evaluation/ and deploys via
# the existing session/deploy.sh mechanism.
set -euo pipefail

REPORT_HTML="/home/opencode0/test-prompts/results/report.html"
REPO_DIR="/home/opencode0/communityservices"
DEPLOY_DIR="$REPO_DIR/communityservices.cc/wwwroot/reports/agent-evaluation"
SESSION_DIR="$REPO_DIR/session"

if [ ! -f "$REPORT_HTML" ]; then
  echo "No report found. Run orchestrate.py, evaluate.py, report_gen.py first." >&2
  exit 1
fi

echo "=== Deploying report to communityservices.cc ==="

# Create the deploy directory and copy report
mkdir -p "$DEPLOY_DIR"
cp "$REPORT_HTML" "$DEPLOY_DIR/index.html"

# Create a small index that redirects to the report
cat > "$DEPLOY_DIR/../index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="refresh" content="0;url=agent-evaluation/">
<title>Reports</title>
</head>
<body>
<p>Redirecting to <a href="agent-evaluation/">agent evaluation report</a>...</p>
</body>
</html>
EOF

echo "Report staged at: $DEPLOY_DIR/index.html"
echo "Size: $(stat -c %s "$DEPLOY_DIR/index.html") bytes"

# Deploy using the existing deploy mechanism (communityservices only)
cd "$REPO_DIR"
echo "=== Running deploy for communityservices.cc ==="
bash "$SESSION_DIR/deploy.sh" communityservices 2>&1 | tail -10

echo "=== Deploy complete ==="
echo "Report available at: https://communityservices.cc/reports/agent-evaluation/"
