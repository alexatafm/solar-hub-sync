.PHONY: help build test-5 test-50 run clean logs railway-login railway-link railway-test railway-deploy railway-logs railway-status

help:
	@echo "Available commands:"
	@echo "  make build         - Build Docker image"
	@echo "  make test-5        - Test with 5 jobs locally"
	@echo "  make test-50       - Test with 50 jobs locally"
	@echo "  make run           - Run full sync locally"
	@echo "  make logs          - View local logs"
	@echo "  make clean         - Clean up Docker containers and images"
	@echo ""
	@echo "Railway commands:"
	@echo "  make railway-login    - Login to Railway"
	@echo "  make railway-link     - Link to Railway project"
	@echo "  make railway-test     - Deploy test (10 jobs) to Railway"
	@echo "  make railway-deploy   - Deploy full sync to Railway"
	@echo "  make railway-logs     - View Railway logs"
	@echo "  make railway-status   - Check Railway status"

build:
	@echo "🔨 Building Docker image..."
	docker-compose build

test-5:
	@echo "🧪 Testing with 5 jobs..."
	docker-compose --profile test up job-sync-test

test-50:
	@echo "🧪 Testing with 50 jobs..."
	MAX_JOBS=50 docker-compose --profile test up job-sync-test

run:
	@echo "🚀 Running full sync..."
	docker-compose up job-sync

logs:
	@echo "📋 Viewing logs..."
	@tail -f logs/sync_jobs.log 2>/dev/null || echo "No logs yet. Run 'make test-5' first."

clean:
	@echo "🧹 Cleaning up..."
	docker-compose down
	docker rmi solarhub-job-sync 2>/dev/null || true
	@echo "✅ Cleanup complete"

# Railway commands
railway-login:
	@echo "🔐 Logging into Railway..."
	railway login

railway-link:
	@echo "🔗 Linking to Railway project..."
	railway link

railway-test:
	@echo "🧪 Deploying test mode to Railway (10 jobs)..."
	railway variables --set "MAX_JOBS=10"
	railway up --detach
	@echo "✅ Test deployment started. Run 'make railway-logs' to view progress."

railway-deploy:
	@echo "🚀 Deploying full sync to Railway..."
	railway variables --set "MAX_JOBS="
	railway redeploy -y
	@echo "✅ Full sync deployment started. Run 'make railway-logs' to monitor."

railway-logs:
	@echo "📋 Viewing Railway logs..."
	railway logs --follow

railway-status:
	@echo "📊 Railway status:"
	railway status

