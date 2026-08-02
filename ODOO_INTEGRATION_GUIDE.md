# Nayo Odoo Integration Guide

Complete guide for integrating the Nayo Loyalty Platform with Odoo ERP.
This covers both the standalone API approach and direct Odoo module integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Option A: API-Based Integration](#option-a-api-based-integration)
5. [Option B: Odoo Module Integration](#option-b-odoo-module-integration)
6. [Data Mapping](#data-mapping)
7. [Sync Workflows](#sync-workflows)
8. [Webhook Configuration](#webhook-configuration)
9. [Scheduled Actions (Cron)](#scheduled-actions-cron)
10. [POS Integration](#pos-integration)
11. [eCommerce Integration](#ecommerce-integration)
12. [Troubleshooting](#troubleshooting)

---

## Overview

Nayo integrates with Odoo as an external loyalty engine. The integration
serves two purposes:

1. **Push customer and transaction data** from Odoo to Nayo for loyalty
   point calculation, tier assignment, and campaign eligibility
2. **Pull loyalty data** from Nayo into Odoo to display member status,
   available rewards, and coupon codes at checkout (POS and eCommerce)

```
    Odoo                              Nayo
+---------------+              +------------------+
| Contacts      |---sync-----> | Members          |
| Sale Orders   |---sync-----> | Transactions     |
| POS Orders    |---sync-----> | Points Engine    |
| Invoices      |---sync-----> | Custom Events    |
| Products      |---labels---> | Earning Rules    |
|               |              |                  |
| Display       |<---status--- | Loyalty Status   |
| Coupons       |<---rewards-- | Reward Catalog   |
| Discounts     |<---coupons-- | Campaign Coupons |
+---------------+              +------------------+
```

---

## Architecture

### API-Based (Recommended for most deployments)

Odoo communicates with Nayo via its REST API. No custom Odoo module
required — you can use Odoo's built-in automation tools:

- **Server Actions** — Trigger API calls on record create/update
- **Automated Actions** — Run API calls based on conditions
- **Scheduled Actions (Cron)** — Periodic batch sync
- **Webhooks** — Real-time event notifications from Nayo back to Odoo

### Odoo Module (For deep integration)

A custom Odoo module (`nayo_loyalty`) that adds:

- Loyalty menu in Odoo
- Sync wizard for bulk operations
- Member status display on partner form
- POS integration for real-time point earning/redemption
- eCommerce integration for reward display at checkout

---

## Prerequisites

### Nayo Side

- Nayo instance running (Docker or dedicated)
- Admin API token generated
- Earning rules configured
- Reward catalog populated (optional)
- Custom event schemas defined for Odoo events (optional)

### Odoo Side

- Odoo 15+ (tested on 16 and 17)
- Administrator access
- `requests` Python library available (bundled with Odoo)
- For module approach: Developer mode enabled

---

## Option A: API-Based Integration

This approach works without installing any Odoo module. Use Odoo's
automation features to push data to Nayo.

### Step 1: Store Nayo Credentials in Odoo

Create system parameters for Nayo connection:

- Settings > Technical > System Parameters
- Add:

| Key | Value |
|---|---|
| `nayo.api_url` | `https://your-nayo-instance.com` |
| `nayo.api_key` | `your-admin-api-token` |
| `nayo.enabled` | `true` |

### Step 2: Add Loyalty Card Number to Partners

Add a custom field on `res.partner` for the loyalty card number:

- Settings > Technical > Fields (or use Odoo Studio)
- Model: `res.partner`
- Field name: `x_loyalty_card_number`
- Type: Char
- Label: "Loyalty Card Number"

### Step 3: Create Server Action to Register Members

Settings > Technical > Server Actions > New:

```python
# Action: Register Partner in Nayo on Create
# Model: res.partner
# Trigger: On Creation

import requests
import json

nayo_url = env['ir.config_parameter'].sudo().get_param('nayo.api_url')
api_key = env['ir.config_parameter'].sudo().get_param('nayo.api_key')

if not nayo_url or not api_key:
    raise UserError("Nayo API not configured")

if record.email:
    # Generate loyalty card number if not set
    card_number = record.x_loyalty_card_number or f"LOY-{record.id:06d}"
    if not record.x_loyalty_card_number:
        record.sudo().write({'x_loyalty_card_number': card_number})

    payload = {
        "firstName": record.name.split()[0] if record.name else "",
        "lastName": " ".join(record.name.split()[1:]) if record.name else "",
        "email": record.email,
        "phone": record.phone or "",
        "loyaltyCardNumber": card_number,
        "country": record.country_id.code if record.country_id else "",
        "city": record.city or ""
    }

    try:
        resp = requests.post(
            f"{nayo_url}/api/member/register",
            json=payload,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            timeout=10
        )
        if resp.status_code not in (200, 201, 409):  # 409 = already exists
            log(f"Nayo sync error: {resp.status_code} {resp.text}")
    except Exception as e:
        log(f"Nayo sync failed: {e}")
```

### Step 4: Create Server Action for Sale Orders

Settings > Technical > Server Actions > New:

```python
# Action: Sync Sale Order to Nayo as Transaction
# Model: sale.order
# Trigger: On state change to 'sale'

import requests

nayo_url = env['ir.config_parameter'].sudo().get_param('nayo.api_url')
api_key = env['ir.config_parameter'].sudo().get_param('nayo.api_key')

if not nayo_url or not api_key:
    raise UserError("Nayo API not configured")

partner = record.partner_id
card_number = partner.x_loyalty_card_number

if not card_number:
    # Skip - partner not enrolled in loyalty program
    return

items = []
for line in record.order_line:
    items.append({
        "sku": line.product_id.default_code or f"PROD-{line.product_id.id}",
        "name": line.product_id.name,
        "quantity": line.product_uom_qty,
        "grossValue": line.price_total,
        "category": line.product_id.categ_id.name or "General",
        "labels": {
            "odoo_product_id": str(line.product_id.id),
            "odoo_line_id": str(line.id)
        }
    })

payload = {
    "documentNumber": record.name,
    "documentType": "sell",
    "purchaseDate": record.date_order.isoformat(),
    "purchasePlace": record.team_id.name if record.team_id else "Odoo",
    "customerLoyaltyCardNumber": card_number,
    "items": items,
    "summary": {"grossValue": record.amount_total},
    "labels": {
        "odoo_sale_order_id": str(record.id),
        "odoo_partner_id": str(partner.id),
        "source": "odoo"
    }
}

try:
    resp = requests.post(
        f"{nayo_url}/api/transaction",
        json=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        },
        timeout=10
    )
    resp.raise_for_status()
except Exception as e:
    log(f"Nayo transaction sync failed for {record.name}: {e}")
```

---

## Option B: Odoo Module Integration

### Module Structure

```
nayo_loyalty/
  __init__.py
  __manifest__.py
  models/
    __init__.py
    res_partner.py
    sale_order.py
    pos_order.py
    nayo_sync.py
  views/
    menu_views.xml
    partner_views.xml
    sync_wizard_views.xml
    pos_templates.xml
  wizards/
    nayo_sync_wizard.py
  static/
    description/
      icon.png
    src/
      js/
        pos_nayo.js
  security/
    security.xml
    ir.model.access.csv
  data/
    cron_data.xml
```

### Key Model: `nayo_sync.py`

```python
from odoo import models, fields, api
import requests
import logging

_logger = logging.getLogger(__name__)


class NayoSync(models.AbstractModel):
    _name = 'nayo.sync'
    _description = 'Nayo Loyalty Sync Service'

    def _get_config(self):
        ICP = self.env['ir.config_parameter'].sudo()
        return {
            'url': ICP.get_param('nayo.api_url'),
            'key': ICP.get_param('nayo.api_key'),
        }

    def _headers(self):
        config = self._get_config()
        return {
            'Authorization': f'Bearer {config["key"]}',
            'Content-Type': 'application/json',
        }

    def sync_partner(self, partner):
        """Register or update a partner in Nayo."""
        config = self._get_config()
        if not config['url'] or not config['key']:
            return False

        card_number = partner.x_loyalty_card_number or f"LOY-{partner.id:06d}"
        if not partner.x_loyalty_card_number:
            partner.sudo().write({'x_loyalty_card_number': card_number})

        payload = {
            "firstName": partner.name.split()[0] if partner.name else "",
            "lastName": " ".join(partner.name.split()[1:]) if partner.name else "",
            "email": partner.email or "",
            "phone": partner.phone or "",
            "loyaltyCardNumber": card_number,
            "country": partner.country_id.code if partner.country_id else "",
            "city": partner.city or ""
        }

        try:
            resp = requests.post(
                f"{config['url']}/api/member/register",
                json=payload,
                headers=self._headers(),
                timeout=10
            )
            return resp.status_code in (200, 201, 409)
        except Exception as e:
            _logger.error(f"Nayo sync error: {e}")
            return False

    def sync_transaction(self, order, document_type='sell'):
        """Send a sale order or POS order as a transaction to Nayo."""
        config = self._get_config()
        if not config['url'] or not config['key']:
            return False

        partner = order.partner_id
        card_number = partner.x_loyalty_card_number
        if not card_number:
            return False

        items = []
        for line in order.order_line if hasattr(order, 'order_line') else order.lines:
            items.append({
                "sku": line.product_id.default_code or f"PROD-{line.product_id.id}",
                "name": line.product_id.name,
                "quantity": getattr(line, 'product_uom_qty', None) or getattr(line, 'qty', 1),
                "grossValue": getattr(line, 'price_total', None) or getattr(line, 'price_subtotal_incl', 0),
                "category": line.product_id.categ_id.name or "General",
            })

        amount = getattr(order, 'amount_total', None) or getattr(order, 'amount_total', 0)
        doc_number = getattr(order, 'name', '') or getattr(order, 'pos_reference', '')

        payload = {
            "documentNumber": doc_number,
            "documentType": document_type,
            "purchaseDate": fields.Datetime.now().isoformat(),
            "customerLoyaltyCardNumber": card_number,
            "items": items,
            "summary": {"grossValue": amount},
            "labels": {
                "odoo_order_id": str(order.id),
                "source": "odoo"
            }
        }

        try:
            resp = requests.post(
                f"{config['url']}/api/transaction",
                json=payload,
                headers=self._headers(),
                timeout=10
            )
            return resp.status_code in (200, 201)
        except Exception as e:
            _logger.error(f"Nayo transaction error: {e}")
            return False

    def get_member_status(self, partner):
        """Fetch loyalty status from Nayo for a partner."""
        config = self._get_config()
        if not config['url'] or not partner.x_loyalty_card_number:
            return None

        try:
            resp = requests.get(
                f"{config['url']}/api/member/{partner.x_loyalty_card_number}/loyalty",
                headers=self._headers(),
                timeout=10
            )
            if resp.status_code == 200:
                return resp.json()
        except Exception as e:
            _logger.error(f"Nayo status fetch error: {e}")
        return None
```

---

## Data Mapping

### Partner (res.partner) to Nayo Member

| Odoo Field | Nayo Field | Notes |
|---|---|---|
| `name` (split) | `firstName`, `lastName` | Split on first space |
| `email` | `email` | Required for registration |
| `phone` | `phone` | Optional |
| `x_loyalty_card_number` | `loyaltyCardNumber` | Auto-generated if empty |
| `country_id.code` | `country` | ISO 2-letter code |
| `city` | `city` | Optional |
| `create_date` | — | Member created date |

### Sale Order (sale.order) to Nayo Transaction

| Odoo Field | Nayo Field | Notes |
|---|---|---|
| `name` | `documentNumber` | e.g., "S00142" |
| `date_order` | `purchaseDate` | ISO 8601 format |
| `partner_id` | `customerLoyaltyCardNumber` | Via loyalty card field |
| `team_id.name` | `purchasePlace` | Sales team name |
| `amount_total` | `summary.grossValue` | Total including tax |
| `order_line[].product_id` | `items[].sku` | Product code |
| `order_line[].product_uom_qty` | `items[].quantity` | Quantity ordered |
| `order_line[].price_total` | `items[].grossValue` | Line total |
| `order_line[].product_id.categ_id` | `items[].category` | Product category |

### POS Order (pos.order) to Nayo Transaction

| Odoo Field | Nayo Field | Notes |
|---|---|---|
| `pos_reference` | `documentNumber` | POS order reference |
| `date_order` | `purchaseDate` | ISO 8601 format |
| `partner_id` | `customerLoyaltyCardNumber` | Via loyalty card field |
| `config_id.name` | `purchasePlace` | POS config name |
| `amount_total` | `summary.grossValue` | Total including tax |
| `lines[].product_id` | `items[].sku` | Product code |
| `lines[].qty` | `items[].quantity` | Quantity |
| `lines[].price_subtotal_incl` | `items[].grossValue` | Line total |

---

## Sync Workflows

### Initial Bulk Sync

For existing Odoo databases, run a bulk sync of all partners and
historical transactions:

```python
# Run from Odoo shell or as a wizard action

# 1. Sync all partners with email
partners = env['res.partner'].search([
    ('email', '!=', False),
    ('customer_rank', '>', 0)
])
nayo = env['nayo.sync']
for partner in partners:
    nayo.sync_partner(partner)
    env.cr.commit()  # Commit in batches

# 2. Sync last 12 months of sale orders
from dateutil.relativedelta import relativedelta
cutoff = fields.Datetime.now() - relativedelta(months=12)
orders = env['sale.order'].search([
    ('state', '=', 'sale'),
    ('date_order', '>=', cutoff),
    ('partner_id.x_loyalty_card_number', '!=', False)
])
for order in orders:
    nayo.sync_transaction(order)
    env.cr.commit()
```

### Incremental Sync

After initial sync, use automated actions for real-time sync:

- **Partner created** -> Register in Nayo
- **Sale order confirmed** -> Send transaction to Nayo
- **POS order paid** -> Send transaction to Nayo
- **Invoice paid** -> Send custom event to Nayo (optional)
- **Return/Refund created** -> Send return transaction to Nayo

---

## Webhook Configuration

Nayo can send webhooks back to Odoo for events like:

- Tier change (member promoted/demoted)
- Reward redeemed
- Campaign coupon generated

### Odoo Webhook Endpoint

Create a controller in your Odoo module to receive Nayo webhooks:

```python
from odoo import http
from odoo.http import request
import json


class NayoWebhookController(http.Controller):

    @http.route('/nayo/webhook', type='json', auth='public',
                methods=['POST'], csrf=False)
    def nayo_webhook(self, **kwargs):
        """Receive webhooks from Nayo."""
        data = request.jsonrequest

        event_type = data.get('type')
        member_id = data.get('memberId')

        if event_type == 'tier_changed':
            # Update partner with new tier info
            partner = request.env['res.partner'].sudo().search([
                ('x_loyalty_card_number', '=', member_id)
            ], limit=1)
            if partner:
                partner.write({
                    'x_loyalty_tier': data.get('newTier', ''),
                })

        elif event_type == 'reward_redeemed':
            # Log reward redemption
            request.env['nayo.redemption'].sudo().create({
                'partner_id': request.env['res.partner'].search([
                    ('x_loyalty_card_number', '=', member_id)
                ], limit=1).id,
                'reward_name': data.get('rewardName', ''),
                'points_spent': data.get('pointsSpent', 0),
                'redeemed_at': data.get('timestamp', ''),
            })

        return {'status': 'ok'}
```

### Register Webhook URL in Nayo

```bash
curl -X POST http://nayo.localhost/api/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-odoo.com/nayo/webhook",
    "events": ["tier_changed", "reward_redeemed", "campaign_coupon_generated"]
  }'
```

---

## Scheduled Actions (Cron)

### Daily Points Expiry Check

```xml
<record id="cron_nayo_daily_sync" model="ir.cron">
    <field name="name">Nayo: Daily Loyalty Sync</field>
    <field name="model_id" ref="model_nayo_sync"/>
    <field name="state">code</field>
    <field name="code">model.daily_sync()</field>
    <field name="interval_number">1</field>
    <field name="interval_type">days</field>
    <field name="numbercall">-1</field>
    <field name="active">True</field>
</record>
```

### Weekly Member Status Refresh

```python
def weekly_status_refresh(self):
    """Refresh loyalty status for all active members."""
    partners = self.env['res.partner'].search([
        ('x_loyalty_card_number', '!=', False),
        ('x_loyalty_card_number', '!=', '')
    ])
    nayo = self.env['nayo.sync']
    for partner in partners:
        status = nayo.get_member_status(partner)
        if status:
            partner.write({
                'x_loyalty_points': status.get('points', 0),
                'x_loyalty_tier': status.get('level', ''),
            })
        self.env.cr.commit()
```

---

## POS Integration

Display loyalty status and allow point redemption at Odoo POS:

### POS JavaScript Extension

```javascript
odoo.define('nayo_loyalty.pos', function (require) {
    "use strict";

    var models = require('point_of_sale.models');
    var screens = require('point_of_sale.screens');
    var rpc = require('web.rpc');

    // Extend the PosModel to fetch loyalty data
    models.PosModel.prototype.models.push({
        model: 'res.partner',
        label: 'loading loyalty data',
        loaded: function(self, partners) {
            // Cache loyalty card numbers
            self.partners_with_loyalty = partners.filter(
                p => p.x_loyalty_card_number
            );
        }
    });

    // Extend the PaymentScreen to show points
    var PaymentScreenWidget = screens.PaymentScreenWidget;
    screens.PaymentScreenWidget.include({
        renderCustomerInfo: function() {
            this._super();
            var client = this.pos.get_client();
            if (client && client.x_loyalty_card_number) {
                // Fetch points from Nayo
                rpc.query({
                    model: 'nayo.sync',
                    method: 'get_member_status',
                    args: [[], client.id]
                }).then(function(status) {
                    if (status) {
                        $('.customer-info').append(
                            '<div class="loyalty-info">' +
                            '<span>Points: ' + status.points + '</span>' +
                            '<span>Tier: ' + status.level + '</span>' +
                            '</div>'
                        );
                    }
                });
            }
        }
    });
});
```

---

## eCommerce Integration

### Show Loyalty Info on Product Pages

Add to your Odoo website theme:

```python
class LoyaltyWebsite(http.Controller):

    @http.route('/loyalty/status', type='json', auth='user')
    def loyalty_status(self):
        """Return current user's loyaltyalty status for display."""
        partner = request.env.user.partner_id
        if not partner.x_loyalty_card_number:
            return {'enrolled': False}

        nayo = request.env['nayo.sync']
        status = nayo.get_member_status(partner)
        if status:
            return {
                'enrolled': True,
                'points': status.get('points', 0),
                'tier': status.get('level', ''),
                'available_rewards': status.get('availableRewards', []),
            }
        return {'enrolled': True, 'points': 0, 'tier': ''}
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|---|---|---|
| 401 Unauthorized | Expired API token | Regenerate token in Nayo admin |
| 409 Conflict on register | Member already exists | Use update endpoint instead |
| Timeout on bulk sync | Too many records at once | Batch sync with `env.cr.commit()` |
| Points not earned | Partner has no card number | Ensure `x_loyalty_card_number` is set |
| Transaction rejected | Missing required fields | Check `items[]` has `sku`, `grossValue` |
| Webhook not received | Odoo URL not publicly accessible | Use ngrok or expose via reverse proxy |
| POS not showing points | JS not loaded | Clear POS browser cache, reload |

### Debug Mode

Enable debug logging for Nayo sync:

```python
import logging
logging.getLogger('nayo.sync').setLevel(logging.DEBUG)
```

### Test Connection

```python
# From Odoo shell
nayo = env['nayo.sync']
config = nayo._get_config()
import requests
resp = requests.get(f"{config['url']}/api/healthcheck", timeout=5)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.json()}")
```

---

## Security Notes

- Store Nayo API keys as Odoo system parameters (encrypted)
- Use HTTPS for both Nayo and Odoo instances
- Validate webhook signatures if Nayo supports them
- Limit API token permissions to minimum required
- Rotate API tokens periodically
- Use separate Nayo instances per Odoo database (data isolation)
