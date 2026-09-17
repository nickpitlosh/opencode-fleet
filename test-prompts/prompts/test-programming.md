# Domain: Test Programming & QA Automation

Design a complete test automation framework for a REST API. Requirements:
1. Support both contract testing (Pact) and end-to-end testing
2. Test data management: factory pattern with Faker, database snapshots
3. Parallel test execution with worker pool, configurable concurrency levels
4. Reporting: JUnit XML, HTML with screenshots, Allure integration
5. CI/CD integration: GitHub Actions workflow with matrix testing (3 OS × 3 Node versions)
6. Flaky test detection: automatic retry with exponential backoff, quarantine mechanism
7. Performance testing: integrate k6 with threshold-based pass/fail
8. Mutation testing: configure Stryker with minimum mutation score threshold
9. Generate sample tests for a Pet Store API (CRUD + auth + pagination + filtering)

Deliver: framework code, sample tests, CI workflow, docker-compose for test env, README
