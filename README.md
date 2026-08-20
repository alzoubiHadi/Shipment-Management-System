# Freight Management System (FMS)

> Graduation Project — Land Freight Transportation Management System

**FMS** is a freight management system designed to organize and automate
land transportation operations between companies, drivers, trucks, and
transport management.

The system covers the transportation lifecycle from shipment request and
pricing, through driver matching and trip execution, to proof of delivery,
financial settlement, compliance, reporting, and driver evaluation.

**الوصف بالعربية:**
نظام ALBA هو نظام لإدارة عمليات النقل البري، يربط الشركات والسائقين وإدارة
التطبيق ضمن منصة موحدة لإدارة طلبات النقل، التسعير، المطابقة، الرحلات،
التتبع، التسليم، العمليات المالية، والامتثال.

---

## 1. Project Objectives

The project aims to replace fragmented and manual freight-management
processes with a centralized digital workflow.

The main objectives are:

- Centralize shipment and transportation operations.
- Allow companies to create and monitor shipment requests.
- Automatically match shipments with eligible drivers.
- Track shipment execution and driver location.
- Manage driver and truck compliance.
- Provide proof of delivery and delivery confirmation.
- Manage company balances and driver financial transactions.
- Support multiple administrative roles and permissions.
- Maintain activity and operational records for auditing.
- Provide operational and financial reports.

---

## 2. System Actors

The system contains three main actor categories:

### Company

A company can:

- Manage its profile.
- Create shipment offers.
- Monitor its shipment offers.
- Track assigned shipments.
- View the assigned driver and truck information.
- Confirm or dispute delivery.
- Rate drivers after completed shipments.
- Submit payment/top-up requests.
- View its financial transactions and account information.

A company cannot access another company's private operational data.

---

### Driver

A driver can:

- Manage personal information.
- Upload and maintain required documents.
- Manage the truck associated with the driver.
- Configure supported transportation destinations.
- Set availability status.
- Receive eligible shipment offers.
- Accept available shipment offers.
- Execute assigned trips.
- Update location using device GPS.
- Update shipment stages.
- Submit Proof of Delivery.
- View financial transactions.
- Request payouts.
- View compliance reports and submit appeals when applicable.

Driver eligibility depends on operational and compliance requirements.

---

### Application Administration

Application administration is divided into:

#### Super Admin

The Super Admin has full system access and can:

- Manage companies.
- Manage drivers.
- Manage trucks.
- Manage shipment operations.
- Manage administrative users.
- Assign permission groups.
- Manage platform settings.
- Access activity logs.
- Manage operational escalation.
- Access all administrative functionality.

The Super Admin implicitly has all permission groups.

#### Sub Admin

Sub Admin accounts receive one or more permission groups. Examples include:

- Finance
- CRM
- Compliance / operational administrative functions

Permissions are composable, meaning a Sub Admin may hold multiple permission
groups simultaneously.

---

## 3. High-Level Workflow

The primary freight workflow is:

```text
Company
  ↓
Create Shipment Offer
  ↓
Automatic / Manual Pricing
  ↓
Driver Eligibility Filtering
  ↓
Driver Matching & Ranking
  ↓
Offer Distribution
  ↓
Driver Acceptance
  ↓
Shipment Assignment
  ↓
Trip Execution & Tracking
  ↓
Proof of Delivery
  ↓
Company Confirmation / Dispute
  ↓
Driver Rating
  ↓
Financial Settlement
```

---

## 4. Shipment Offer & Pricing

Companies can create shipment offers containing transportation requirements
such as destination, truck type, cargo information, and pickup details.

### Automatic Pricing

The system determines the shipment price from the configured price list
based on shipment parameters, using a zone-based lane first, then a
country-level fallback:

1. **Zone lane** — an exact price-list entry for the specific origin/destination
   zone pair, if one exists.
2. **Country fallback** — a broader country-to-country rate if no zone-level
   entry is available.
3. **Manual pricing** — if neither produces a usable price.

The suggested price is also adjusted by a recent-market reference (a rolling
90-day median where enough recent samples exist, otherwise the historical
median) and an administrator-controlled market-adjustment percentage. The
server always recomputes the final price itself rather than trusting a
reference price supplied by the client.

### Manual Pricing

If no automatic price is available, the offer enters:

`awaiting_manual_price`

An authorized administrative user can provide the required price before
matching begins.

---

## 5. Driver Matching Engine

The matching system follows two main stages:

### Stage 1 — Eligibility Filtering

Drivers that do not satisfy mandatory conditions are removed before ranking.
Eligibility rules include conditions such as:

- Driver account approval.
- Driver availability.
- Active compliance status.
- Valid required documents.
- Supported transportation destination.
- Cross-border residency requirements where applicable.
- Truck and operational compatibility (type and load capacity).

Mandatory eligibility rules are never intentionally weakened simply to
produce a match.

---

### Stage 2 — Weighted Ranking

Eligible drivers are ranked using a configurable weighted score. The current
default weights (`platform_settings`, 2026-08-27 rebalance) are:

| Factor | Default Weight |
|---|---:|
| Geographic proximity | 30% |
| Route/zone experience | 25% |
| Driver rating | 20% |
| Acceptance rate | 15% |
| Fairness (idle time since last offer) | 10% |

All five weights are configurable through platform settings.

This implementation is a **rule-based weighted scoring algorithm**, not a
machine-learning model. This design was selected because it is:

- Explainable.
- Predictable.
- Easy to audit.
- Easy to configure.
- Suitable for the current project requirements.

---

## 6. Geographic Distance

Driver proximity is currently estimated using the **Haversine formula**,
comparing the driver's last known location to the shipment's origin
coordinates.

This approach provides a lightweight solution without requiring an external
routing service.

### Limitation

Haversine calculates straight-line geographic distance rather than actual
road distance. It does not consider:

- Road networks.
- Traffic.
- Border crossings.
- Road restrictions.
- Estimated travel time.

A routing engine can be integrated in a future production version to provide
road distance and ETA.

---

## 7. Matching Batches & Escalation

Eligible drivers are not necessarily notified all at once. The matching
engine supports batch-based offer distribution.

```text
Top eligible drivers
  ↓
First Matching Batch
  ↓
Response Window
  ↓
No Acceptance
  ↓
Next Matching Batch
  ↓
No Eligible Drivers Remaining
  ↓
Administrative Escalation
```

Batch size and matching timeout can be controlled through platform settings.
This approach reduces unnecessary offer broadcasting and allows higher-ranked
drivers to receive priority.

---

## 8. Safe Shipment Assignment

A critical requirement is preventing two drivers from accepting the same
shipment offer simultaneously. The backend uses database transactions and
row locking during offer acceptance.

Conceptually:

`DB Transaction → Lock Offer → Revalidate → Accept → Assign → Commit`

If another driver attempts to accept an already-accepted offer, the request
is rejected. This protects the system from race conditions and duplicate
assignment — the same locking pattern is also applied to payout confirmation,
delivery confirmation, and manual balance adjustments.

---

## 9. Maps & Location Services

The project uses several technologies for map and location functionality.

### OpenStreetMap

OpenStreetMap provides the geographic map data used by the application (via
direct tile-server URLs) — chosen specifically to avoid a paid/API-key-gated
mapping provider for a graduation project with no production billing.

### flutter_map

`flutter_map` is the Flutter mapping library used to display map content
inside the application.

### Geolocator

`geolocator` is used to access device location services and obtain latitude
and longitude, including a background-tracking mode tied to the driver's
active-trip state.

The general location flow is:

```text
Device GPS
  ↓
Geolocator
  ↓
Flutter Application
  ↓
REST API
  ↓
Laravel Backend
  ↓
Driver Location
```

Location information is then used for shipment tracking and matching.

---

## 10. Shipment Lifecycle

After a driver accepts an offer, the transportation operation continues
through the shipment lifecycle. The system supports:

- Shipment assignment.
- Operational shipment stages.
- Driver location updates.
- Shipment comments.
- Delivery.
- Proof of Delivery.
- Company delivery confirmation.
- Delivery dispute.
- Administrative dispute resolution.
- Driver rating.

---

## 11. Proof of Delivery

The system includes a Proof of Delivery workflow. After reaching the
delivery stage, delivery evidence — a photo captured directly from the
driver's camera (`image_picker`) — can be submitted.

The company can then:

- Confirm the delivery, or
- Dispute the delivery.

Disputed deliveries can be reviewed and resolved through the appropriate
administrative workflow.

---

## 12. Driver Rating

Companies can rate drivers after shipment completion. Driver performance
data contributes to future matching decisions.

```text
Completed Shipment
  ↓
Driver Rating
  ↓
Updated Driver Performance
  ↓
Future Matching Score
```

Authorized administration can also manage relevant driver performance and
compliance information.

---

## 13. Compliance Management

The system includes driver/truck/company compliance functionality. Supported
operations include:

- Document management (upload, renewal, previous-document history).
- A daily scheduled expiry check with 30/15/7/1-day notifications.
- Compliance reports and administrative resolution.
- Driver suspension and reactivation.
- Driver appeals and appeal resolution.
- A grace period governing exactly when eligibility is restored after
  renewal.

Compliance status directly affects driver eligibility for future shipment
offers (a hard block, not a soft warning).

---

## 14. Financial Management

The system contains a financial ledger for transportation operations.
Financial functionality includes:

- Company account transactions.
- Credit limits, with reserved vs. committed amounts tracked separately to
  avoid overcommitting available credit.
- Shipment charges.
- Payment/top-up orders.
- Driver payout requests.
- Financial adjustments.
- Financial reporting.

All monetary calculations use PHP's arbitrary-precision `bcmath` extension
rather than floating-point numbers, to avoid rounding-error drift in
balances over time.

---

### Financial Dual Control

Sensitive manual financial adjustments use a dual-control approach:

```text
Finance User
  ↓
Proposes Adjustment
  ↓
Super Admin
  ↓
Approve / Reject
```

This reduces the risk associated with a single administrative account both
making and approving the same sensitive financial change.

---

## 15. Notifications

The application supports both in-app notifications and push notifications.

### Firebase Cloud Messaging

Firebase Cloud Messaging (FCM) is used for push notification delivery.

```text
Laravel Backend
  ↓
Notification Event
  ↓
Firebase Cloud Messaging
  ↓
Flutter Application
  ↓
User Device
```

The application registers device FCM tokens with the backend. Every event is
also always recorded to the in-app notification center regardless of whether
push delivery succeeds. Examples of notification events include: new matched
shipment offer, pricing-related actions, shipment/delivery updates, document
expiry alerts, and administrative/financial events.

---

## 16. Authentication & Security

### Laravel Sanctum

Laravel Sanctum provides token-based authentication between the Flutter
application and the Laravel REST API.

```text
User Login
  ↓
Laravel Authentication
  ↓
Access Token
  ↓
Flutter Client
  ↓
Authenticated API Requests
```

### Authorization

Authentication determines *who* the user is; authorization determines *what*
the user is allowed to do. The system uses role and permission checks to
restrict administrative functionality — Sub Admin permissions are enforced
through permission middleware, e.g. `permission:finance`. The Super Admin
has full administrative access.

---

## 17. Activity Logging

Administrative activity logging is available to support accountability,
troubleshooting, security reviews, and administrative auditing. Sensitive
administrative operations remain traceable.

---

## 18. Technology Stack

| Layer | Technology |
|---|---|
| Client Application | Flutter / Dart |
| Backend | Laravel 12 |
| Backend Language | PHP 8.2+ |
| API Architecture | REST API / JSON |
| Authentication | Laravel Sanctum |
| Maps | OpenStreetMap |
| Flutter Map Library | flutter_map |
| Location | geolocator |
| Geographic Coordinates | latlong2 |
| Push Notifications | Firebase Cloud Messaging |
| HTTP Client | Dart `http` package |
| Local Preferences | shared_preferences |
| File Selection | file_picker |
| Proof of Delivery Capture | image_picker |
| Reporting Charts | fl_chart |
| Database | PostgreSQL (managed via Neon) |
| Monetary Precision | PHP `bcmath` |
| Hosting / Deployment | Render.com (Docker) |
| Backend Testing | PHPUnit (Laravel Feature tests) |

---

## 19. Why Flutter?

Flutter was selected because it provides:

- A single codebase for multiple platforms and roles (driver/company/admin).
- Compiles to native code rather than running in a WebView, for
  near-native performance and animation.
- Strong mobile UI capabilities and a consistent look across Android/iOS.
- Good support for GPS and device services.
- Firebase integration.
- Mapping libraries.
- Rapid UI development via Hot Reload.
- Reusable components (the app's own `widgets/` design-system kit).

The Flutter application represents the client/presentation layer of the
system. Business rules are primarily enforced by the backend rather than
relying only on the user interface.

---

## 20. Why Laravel?

Laravel was selected for the backend because it provides:

- Structured REST API development.
- Request validation.
- Eloquent ORM.
- Authentication with Sanctum.
- Middleware.
- Database migrations.
- Database transactions and row locking.
- Testing support.
- Maintainable separation of application logic (Controllers + Services).

Laravel contains the central business logic of the system.

---

## 21. System Architecture

```text
                  ┌───────────────────┐
                  │   Flutter Client  │
                  │                   │
                  │ UI / GPS / Maps   │
                  └─────────┬─────────┘
                            │
                       REST / JSON
                            │
                  ┌─────────▼─────────┐
                  │    Laravel API    │
                  │                   │
                  │ Business Logic    │
                  │ Authentication    │
                  │ Matching          │
                  │ Finance           │
                  └──────┬─────┬──────┘
                         │     │
              ┌──────────▼┐   └──────────────┐
              │ PostgreSQL│              Firebase FCM
              │  (Neon)   │                   │
              └───────────┘                   ▼
                                      Push Notifications

Flutter Map
     │
     ▼
OpenStreetMap

Device GPS
     │
     ▼
Geolocator
```

---

## 22. Project Structure

```text
Trucks/
├── app/       ← Flutter client (lib/Screens, lib/API, lib/models, lib/theme, lib/widgets)
└── server/    ← Laravel API (app/Http/Controllers, app/Services, app/Models, database/migrations, tests)
```

## 23. Running Locally

### Backend (Laravel)

```bash
cd server
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### Client (Flutter)

```bash
cd app
flutter pub get
flutter run
```

### Automated Tests

```bash
cd server
php artisan test
```

---

## Note

Real database credentials and any generated data containing personal
information (license numbers, phone numbers, etc.) are intentionally not
committed to this repository — see `.gitignore`.
