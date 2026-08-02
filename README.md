# Nayo

<p align="center">
  <strong>The API-first, composable loyalty engine powering enterprise brands worldwide.</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#api-overview">API Docs</a> •
  <a href="backend/doc/index.rst">Technical Docs</a> •
  <a href="#editions">Editions</a>
</p>

---

## What is Nayo?

Nayo is a **headless, API-first loyalty platform** designed for innovators and visionaries who want to implement effective loyalty programs that cut across multiple touchpoints — online, in-store, mobile, and beyond.

Unlike old-fashioned, monolithic loyalty software, Nayo provides a **composable loyalty engine** that integrates seamlessly with any tech stack. Whether you're running a custom e-commerce platform, a CRM system, a POS network, or **Odoo ERP**, the Nayo API slots in as your dedicated loyalty logic engine — without replacing any existing infrastructure.

**"Nayo"** means *"You have it"* or *"With it"* — because with Nayo, you have everything you need to build powerful loyalty programs.

---

## Key Features

### Gamified Loyalty Mechanics

A full behavioral mechanics toolkit — composable via API, configurable without code:

| Mechanic | Description |
|---|---|
| **Tiers & Rank Progression** | Dynamic status levels with progression bars that create emotional connection to your brand |
| **Challenges & Missions** | Multi-step behavioral engagement loops rewarding transactional and non-transactional actions |
| **Points & Multi-Wallet** | Flexible earn-and-burn with multiple wallets per member; convert any event into loyalty currency |
| **Rewards & Coupons** | Reward catalogs with instant or locked incentives, based on tier, behavior, or segment |
| **Gamified Referrals** | Multi-tier referral mechanics that turn engaged members into acquisition engines |
| **Spin the Wheel & Games** | Spin the Wheel, Scratch & Win, lotteries, and raffles for high-engagement moments |
| **Badges & Achievements** | Recognition mechanics triggered by transactions, behaviors, and custom events |
| **Leaderboards & Rankings** | Dynamic competition and community mechanics that reward your most engaged members |

### Smart Segmentation & Campaigns

- **Customer Segments** — Create dynamic segments based on behavior, spend, tier, or custom attributes
- **Earning Rules** — Define flexible point-earning rules tied to transactions, custom events, or behaviors
- **Campaigns** — Launch targeted coupon and reward campaigns with full lifecycle management
- **Custom Events** — Define and trigger custom events from any source (webhooks, mobile apps, POS, Odoo)
- **Personalized Rewards Catalog** — Manage reward categories, coupon codes, images, and eligibility

### Analytics & Reporting

- **Transaction analytics** — Track purchase patterns and revenue impact
- **Member analytics** — Monitor engagement, churn signals, and segment growth
- **Tier analytics** — Measure progression and retention across loyalty tiers
- **Campaign analytics** — Evaluate redemption rates and ROI per campaign
- **Referral analytics** — Track referral-driven acquisition and conversion
- **Data export** — Full data import/export with API and file-based workflows

### API-First Architecture

Nayo is **100% REST API-driven** — built for developers who need speed, flexibility, and reliability:

- **RESTful API** with full CRUD operations on every entity
- **Swagger/OpenAPI documentation** at `/doc`
- **JWT-based authentication** (admin tokens, member tokens, refresh tokens)
- **Webhooks** for real-time event notifications
- **120ms average API response time**
- **99.99% uptime SLA** (commercial editions)
- **Postman collections** for rapid prototyping

### Security & Compliance

- **ISO 27001** and **ISO 9001** certified
- **GDPR compliant** with built-in member anonymization and data management
- **OWASP Top 10** and **CWE/SANS Top 25** tested
- **RBAC (Role-Based Access Control)** with granular permission management
- **Audit logs** with full system activity tracking
- **Data encryption** at rest and in transit

---

## Standalone or Integrated — Your Choice

Nayo's headless architecture means the API runs as an **independent loyalty microservice** that any system can connect to. This gives you two powerful deployment paths:

### Path 1: Standalone API for Any System

```
+----------------+      +----------------+      +----------------+
|  Your Website  |      |  Mobile App    |      |   POS System   |
+-------+--------+      +-------+--------+      +-------+--------+
        |                       |                       |
        +-----------+-----------+-----------+-----------+
                    |    REST API / JWT     |
              +-----v-------------------------v-----+
              |        Nayo Loyalty Engine          |
              |  +---------+---------+--------+     |
              |  | Points  |  Tiers  |Rewards |     |
              |  |Campaigns|Segments |Referrals|    |
              |  +---------+---------+--------+     |
              +-------------------------------------+
```

**Works with any system:**

- Custom e-commerce platforms (Magento, Shopify, WooCommerce, etc.)
- CRM systems (Salesforce, HubSpot, Zoho)
- CDPs and Marketing Automation tools
- POS and in-store systems
- Mobile applications (iOS, Android, React Native, Flutter)
- Any system that can make HTTP requests

**Benefits:**
- No need to replace your existing stack
- Plug in loyalty logic without disrupting current operations
- Scale independently from your core platform
- Full data separation with independent instances

### Path 2: Odoo Integration

```
+--------------------------------------------------+
|                   Odoo ERP                        |
|  +------+ +------+ +-----+ +------+ +--------+  |
|  |Sales | | CRM  | | POS | | eComm| |Accounting| |
|  +--+---+ +--+---+ +--+--+ +--+---+ +---+----+  |
|     +--------+-------+-------+---------+        |
|                     |                            |
|            Odoo API / Webhooks                   |
|                     |                            |
+---------------------+----------------------------+
                      | REST API / JWT
            +---------v----------+
            |    Nayo API        |
            | (Loyalty Engine)   |
            +--------------------+
```

**Odoo-specific integration scenarios:**

| Odoo Module | Loyalty Integration |
|---|---|
| **Odoo POS** | Earn points at checkout, redeem rewards in-store, apply tier-based discounts |
| **Odoo eCommerce** | Points on purchases, referral programs, gamified engagement on product pages |
| **Odoo CRM** | Tier-based lead scoring, reward-driven customer nurturing campaigns |
| **Odoo Sales** | B2B loyalty programs, volume-based earning rules, partner incentives |
| **Odoo Invoicing** | Points on invoice payment, cashback programs, automatic reward triggers |
| **Odoo Events** | Attendance badges, event check-in missions, speaker engagement rewards |

**Benefits for Odoo merchants:**
- Add a full-featured loyalty layer without custom Odoo module development
- Sync customer data via Odoo's API and Nayo REST API
- Trigger loyalty events on Odoo sales orders, invoices, POS transactions
- Use Odoo webhooks or scheduled actions to push events to Nayo
- Keep loyalty logic decoupled — upgrade Odoo or Nayo independently
- Manage all loyalty mechanics from the Nayo admin panel, not Odoo's limited loyalty module

**Quick Odoo integration example:**

```python
import requests

NAYO_URL = "https://your-nayo-instance.com"
API_KEY = "your-api-key"

# 1. Register a customer from Odoo
member = requests.post(f"{NAYO_URL}/api/member/register", json={
    "firstName": customer.name,
    "lastName": customer.lastname,
    "email": customer.email,
    "phone": customer.phone,
    "loyaltyCardNumber": customer.loyalty_card_number
}, headers={"Authorization": f"Bearer {API_KEY}"})

# 2. Record a transaction (e.g., from Odoo POS or Sales Order)
transaction = requests.post(f"{NAYO_URL}/api/transaction", json={
    "documentNumber": sale_order.name,
    "purchaseDate": sale_order.date_order.isoformat(),
    "documentType": "sell",
    "posId": pos_config.id,
    "items": [{
        "sku": product.default_code,
        "name": product.name,
        "quantity": line.product_uom_qty,
        "grossValue": line.price_total,
        "category": product.categ_id.name
    }],
    "customerLoyaltyCardNumber": customer.loyalty_card_number
}, headers={"Authorization": f"Bearer {API_KEY}"})

# 3. Check member's loyalty status
status = requests.get(
    f"{NAYO_URL}/api/member/{member_id}/loyalty",
    headers={"Authorization": f"Bearer {API_KEY}"}
)
print(f"Points: {status['points']}, Tier: {status['level']}")
```

---

## Business Applications

There are many ways to use Nayo's headless loyalty architecture:

- **Full loyalty programs** for offline and online channels
- **Mobile loyalty applications** (native or hybrid)
- **Employee motivational programs**
- **Loyalty modules embedded in your own SaaS product**
- **B2B partner incentive programs**
- **Omnichannel retail loyalty** (POS + eCommerce + mobile)
- **Gamified customer engagement** (challenges, missions, leaderboards)

### Industry Focus

| Industry | Use Cases |
|---|---|
| **Omnichannel Retail** | Unified earn-and-burn across stores, online, and mobile |
| **eCommerce** | Points, referrals, gamification for digital storefronts |
| **QSR / Food & Beverage** | Stamp cards, order frequency rewards, app-based ordering |
| **Sports & Football Clubs** | Fan engagement, ticket reselling rewards, match attendance |
| **Financial Services** | Card-linked rewards, spending tiers, referral bonuses |
| **Insurance** | Behavioral engagement, health tracking rewards |
| **CPG & D2C** | Brand loyalty across third-party retailers |
| **Entertainment** | Event attendance, content engagement rewards |

---

## Architecture

```
+----------------------------------------------------------------+
|                        Frontend Apps                           |
|   Admin Panel  |  Customer Panel  |  Merchant Panel  |  Mobile |
+-------+--------+--------+---------+---------+--------+--------+
        |                 |                   |
    +---v-----------------v-------------------v------+
    |              Nginx (Reverse Proxy)              |
    +------------------------+------------------------+
                             |
    +------------------------v------------------------+
    |           PHP-FPM (Symfony Backend)             |
    |                                                 |
    |  +----------+ +----------+ +-----------------+  |
    |  | Members  | | Campaigns| | Points / Tiers  |  |
    |  | Segments | | Rewards  | | Referrals       |  |
    |  | Events   | | Analytics| | Achievements    |  |
    |  +----------+ +----------+ +-----------------+  |
    +-------+----------------------------+------------+
            |                            |
    +-------v-------+         +----------v---------+
    |  PostgreSQL   |         |  Elasticsearch     |
    |  (Database)   |         | (Search/Analytics) |
    +---------------+         +--------------------+
```

**Tech Stack:**
- **Backend:** PHP / Symfony Framework
- **Frontend:** Angular.js (Admin, Customer, and Merchant panels)
- **Database:** PostgreSQL
- **Search:** Elasticsearch
- **Containerization:** Docker & Docker Compose
- **Orchestration:** Kubernetes (production)
- **Mail:** MailHog (development)
- **CI/CD:** Travis CI, GitLab CI

---

## Quick Start

### Prerequisites

- [Docker](https://www.docker.com/) and Docker Compose
- OR [Vagrant](https://www.vagrantup.com/downloads.html) + [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/iamtutumo/Nayo.git
cd Nayo

# Start all services
cd docker
docker-compose up -d

# Initialize and set up the database
docker-compose exec --user=www-data php phing setup

# Add to /etc/hosts (Linux/macOS) or C:\Windows\System32\drivers\etc\hosts (Windows)
# 127.0.0.1  nayo.localhost
```

### Option 2: Vagrant

```bash
vagrant up
vagrant ssh

# Inside the VM
docker-compose -f docker/docker-compose.yml up -d
docker-compose -f docker/docker-compose.yml exec --user=www-data php phing setup
```

### Access Points

After setup, the following services are available:

| Service | URL |
|---|---|
| **Admin Panel** | [http://nayo.localhost:8182](http://nayo.localhost:8182) |
| **Customer Panel** | [http://nayo.localhost:8183](http://nayo.localhost:8183) |
| **Merchant Panel** | [http://nayo.localhost:8184](http://nayo.localhost:8184) |
| **REST API** | [http://nayo.localhost](http://nayo.localhost) |
| **API Documentation** | [http://nayo.localhost/doc](http://nayo.localhost/doc) |
| **MailHog** | [http://nayo.localhost:8186](http://nayo.localhost:8186) |

**Default credentials:** `admin` / `open`

### For Developers

```bash
# Build base docker images for development
./docker/base/build_dev.sh

# Run in development mode (with source code mounted)
docker-compose -f docker/docker-compose.dev.yml up -d

# Set up the database
docker-compose -f docker/docker-compose.dev.yml exec --user=www-data php phing setup
```

Development mode URLs:

| Service | URL |
|---|---|
| **Admin Panel** | [http://nayo.localhost:8081/admin](http://nayo.localhost:8081/admin) |
| **Customer Panel** | [http://nayo.localhost:8081/client](http://nayo.localhost:8081/client) |
| **Merchant Panel** | [http://nayo.localhost:8081/pos](http://nayo.localhost:8081/pos) |
| **REST API** | [http://nayo.localhost](http://nayo.localhost) |
| **API Documentation** | [http://nayo.localhost/app_dev.php/doc](http://nayo.localhost/app_dev.php/doc) |

---

## API Overview

Nayo exposes a comprehensive REST API with JWT authentication. Key resource endpoints:

| Resource | Endpoints | Description |
|---|---|---|
| **Members** | `/api/member/*` | Registration, profiles, loyalty status, activation |
| **Points/Units** | `/api/points/*` | Earn, spend, transfer, block, expire points |
| **Tiers** | `/api/tier/*` | Tier management, assignment, progression |
| **Campaigns** | `/api/campaign/*` | Create, manage, and simulate campaigns |
| **Rewards** | `/api/reward/*` | Reward catalog, purchases, coupons, redemption |
| **Segments** | `/api/segment/*` | Customer segmentation and targeting |
| **Transactions** | `/api/transaction/*` | Record and query purchase transactions |
| **Custom Events** | `/api/event/*` | Define schemas and trigger custom events |
| **Achievements** | `/api/achievement/*` | Badge and achievement management |
| **Referrals** | `/api/referral/*` | Referral program management |
| **Analytics** | `/api/analytics/*` | Transaction, member, tier, campaign analytics |
| **Channels** | `/api/channel/*` | Multi-channel configuration |
| **Stores/Tenants** | `/api/store/*` | Multi-tenant and store management |
| **Settings** | `/api/settings/*` | Platform configuration |
| **Audit** | `/api/audit/*` | System logs and export |
| **Import/Export** | `/api/import/*`, `/api/export/*` | Bulk data operations |

> Full interactive API documentation available at `/doc` when running locally.

---

## Editions

Nayo is available in multiple editions:

| Feature | Community (This Repo) | Hosted | Dedicated |
|---|---|---|---|
| All loyalty & gamification features | Basic | Full | Full |
| REST API | Yes | Yes | Yes |
| Admin/Customer/Merchant panels | Yes | Yes | Yes |
| Members limit | Up to 200 | Unlimited | Unlimited |
| Hosting | Self-hosted | Cloud (AWS) | Self-hosted |
| High performance & scalability | — | Yes | Yes |
| Maintenance & support | Community | Yes | Yes |
| Whitelabel | — | Yes | Yes |
| Kubernetes orchestration | — | Yes | Yes |
| 99.99% uptime SLA | — | Yes | Yes |

> **For commercial projects with more than 200 members**, we strongly recommend the Hosted or Dedicated edition. Contact us for pricing and demos.

---

## Screenshots

![Admin Cockpit](https://user-images.githubusercontent.com/3582562/54033263-1db79500-41b4-11e9-8f2d-9b91acce50cf.png)

---

## Performance & Scalability

Nayo is built for enterprise scale:

- **1B+ loyalty events** processed per month
- **1,500+ concurrent API calls** with sub-1-second response times
- **120ms average API response time**
- **Kubernetes-orchestrated** on AWS infrastructure
- **99.99% uptime** with multi-region availability

---

## JWT Keys

Running `phing setup` generates JWT public/private keys automatically. To generate manually:

```bash
phing generate-jwt-keys
```

---

## Vagrant Helper Commands

| Command | Description |
|---|---|
| `vagrant provision --provision-with sync` | Sync current directory |
| `vagrant provision --provision-with build` | Rebuild Docker base images |

---

## Documentation

| Resource | Location |
|---|---|
| **User Guide** | [backend/doc/userguide](backend/doc/userguide/index.rst) |
| **Developer Guide** | [backend/doc/developer](backend/doc/developer/index.rst) |
| **REST API Reference** | [backend/doc/api](backend/doc/api/index.rst) |
| **Cookbook** | [backend/doc/cookbook](backend/doc/cookbook/index.rst) |

---

## Contributing

Contributions are welcome! Please read the `CONTRIBUTING.md` file for guidelines on submitting pull requests, reporting issues, and proposing features.

---

## License

This project is licensed under the **Nayo License Agreement** (based on MIT).

- **Community Edition:** Free for non-commercial use or commercial use with up to 200 customers
- **Enterprise Edition:** Required for commercial use with more than 200 customers

See the [LICENSE](LICENSE) file for full terms.

---

<p align="center">
  <em>Built with care by the Nayo team — giving you everything you need for powerful loyalty programs.</em>
</p>
