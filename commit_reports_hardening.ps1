git add server/app/Http/Controllers/ReportController.php `
        server/routes/api.php `
        server/tests/Feature/ShipmentBusinessRulesTest.php `
        app/lib/API/ReportService.dart `
        app/lib/Screens/DriverReportsPage.dart `
        app/lib/Screens/CompanyReportsPage.dart `
        app/lib/Screens/ReportsHomePage.dart `
        app/lib/Screens/DriverBalancePage.dart `
        app/pubspec.yaml

git commit -F commit_reports_hardening_message.txt

git push origin new-design
