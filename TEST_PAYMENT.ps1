# ============================================
# PAYMENT SYSTEM COMPLETE TEST
# ============================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CAMPUS MART - PAYMENT SYSTEM TEST                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Kill any existing processes
Write-Host "Step 1: Cleaning up old processes..." -ForegroundColor Yellow
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "✅ Done`n" -ForegroundColor Green

# Step 2: Check JAR file
Write-Host "Step 2: Checking backend JAR..." -ForegroundColor Yellow
$jarPath = "c:\Users\HP\All_Projects\campus-mart-v2\backend\target\campus-mart-backend-2.0.0.jar"
if (Test-Path $jarPath) {
    Write-Host "✅ JAR found: $jarPath`n" -ForegroundColor Green
} else {
    Write-Host "❌ JAR not found!`n" -ForegroundColor Red
    exit 1
}

# Step 3: Start Backend
Write-Host "Step 3: Starting Backend on port 8081..." -ForegroundColor Yellow
$backendProcess = Start-Process -FilePath "java" `
    -ArgumentList "-jar", $jarPath `
    -WorkingDirectory "c:\Users\HP\All_Projects\campus-mart-v2\backend" `
    -PassThru `
    -NoNewWindow

Start-Sleep -Seconds 12

# Test backend health
$backendHealthUrl = "http://localhost:8081/api/payments/config"
Write-Host "Testing Backend: $backendHealthUrl" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $backendHealthUrl -UseBasicParsing -TimeoutSec 5
    $json = $response.Content | ConvertFrom-Json
    Write-Host "✅ Backend is working!`n" -ForegroundColor Green
    Write-Host "   Response: $($response.Content)`n" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Backend failed: $_`n" -ForegroundColor Red
    exit 1
}

# Step 4: Start Frontend
Write-Host "Step 4: Starting Frontend on port 3000..." -ForegroundColor Yellow
Start-Process -FilePath "npm" `
    -ArgumentList "start" `
    -WorkingDirectory "c:\Users\HP\All_Projects\campus-mart-v2\frontend" `
    -NoNewWindow

Start-Sleep -Seconds 15
Write-Host "✅ Frontend started (check http://localhost:3000)`n" -ForegroundColor Green

# Step 5: Summary
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  🎉 PAYMENT SYSTEM READY FOR TESTING!                     ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "SERVICES RUNNING:" -ForegroundColor Yellow
Write-Host "  ✅ Backend: http://localhost:8081/api" -ForegroundColor Cyan
Write-Host "  ✅ Frontend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "  ✅ Razorpay Key: rzp_test_SfRn4qcORkXcHX`n" -ForegroundColor Cyan

Write-Host "TEST FLOW:" -ForegroundColor Yellow
Write-Host "  1. Open http://localhost:3000" -ForegroundColor White
Write-Host "  2. Login as SELLER → Add Item (₹2,199)" -ForegroundColor White
Write-Host "  3. Login as BUYER → Find Item" -ForegroundColor White
Write-Host "  4. Click: 💳 Pay ₹2,199 Securely" -ForegroundColor White
Write-Host "  5. Select UPI → Enter: success@razorpay" -ForegroundColor White
Write-Host "  6. Confirm and Check Orders page`n" -ForegroundColor White

Write-Host "TEST CREDENTIALS:" -ForegroundColor Yellow
Write-Host "  UPI: success@razorpay (Auto-approved)" -ForegroundColor Cyan
Write-Host "  Card: 4111 1111 1111 1111" -ForegroundColor Cyan
Write-Host "  Expiry: 12/25, CVV: 123`n" -ForegroundColor Cyan

Write-Host "Both services are now running. Keep this window open!" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Yellow

# Keep the script running
while ($true) {
    Start-Sleep -Seconds 60
}
