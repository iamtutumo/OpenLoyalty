# Nayo Points System Guide

Complete guide to the Nayo loyalty points system, covering earning rules,
point transfers, multi-wallet support, expiry policies, and integration
with Odoo and other external systems.

---

## Table of Contents

1. [Overview](#overview)
2. [Point Types](#point-types)
3. [Earning Points](#earning-points)
4. [Spending Points](#spending-points)
5. [Transferring Points](#transferring-points)
6. [Blocking and Unblocking](#blocking-and-unblocking)
7. [Expiry and Lifetime](#expiry-and-lifetime)
8. [Multi-Wallet](#multi-wallet)
9. [Earning Rules Configuration](#earning-rules-configuration)
10. [Points Calculation Examples](#points-calculation-examples)
11. [API Reference](#api-reference)
12. [Odoo Integration](#odoo-integration)
13. [Admin Panel Operations](#admin-panel-operations)

---

## Overview

Nayo uses a flexible points (units) system as the core loyalty currency.
Points can be:

- **Earned** through transactions, custom events, referrals, and campaigns
- **Spent** on rewards, coupons, and experiences
- **Transferred** between members
- **Blocked** temporarily for pending redemptions
- **Expired** based on configurable policies

All point operations are event-sourced, meaning every change is recorded
as an immutable transfer record with full audit trail.

---

## Point Types

Nayo supports multiple point/unit types through its multi-wallet system:

| Type | Description | Use Case |
|---|---|---|
| **Standard Points** | Default loyalty currency | Earn-and-burn programs |
| **Bonus Points** | Campaign-specific bonus | Limited-time promotions |
| **Referral Points** | Earned through referrals | Referral programs |
| **Status Points** | Used only for tier calculation | Tier progression |
| **Custom Wallets** | Admin-defined point types | Multi-currency programs |

---

## Earning Points

Points are earned through multiple channels:

### 1. Transaction-Based Earning

When a transaction is registered, Nayo evaluates all active earning rules
and awards points accordingly.

```
POST /api/transaction
```

The system automatically:
1. Looks up the member by loyalty card number
2. Evaluates all active earning rules against the transaction
3. Creates point transfers for each matching rule
4. Recalculates tier status if applicable

### 2. Manual Award (Admin)

Admins can manually add points to any member:

```
POST /api/points/transfer
{
  "memberId": "member-uuid",
  "value": 500,
  "type": "add",
  "comment": "Customer service goodwill",
  "issuer": "admin@company.com"
}
```

### 3. Custom Event Earning

Points can be awarded based on custom events (e.g., app install,
review submitted, profile completed):

```
POST /api/event
{
  "name": "app_installed",
  "memberId": "member-uuid",
  "data": {
    "platform": "android",
    "version": "2.1.0"
  }
}
```

### 4. Referral Earning

When a referred friend registers and makes a first purchase:

```
POST /api/referral
{
  "referrerId": "member-uuid",
  "referredEmail": "friend@example.com"
}
```

---

## Spending Points

Points are spent through:

### 1. Reward Redemption

```
POST /api/reward/{reward_id}/buy
{
  "memberId": "member-uuid"
}
```

This creates a spend transfer deducting the reward cost from the
member's balance.

### 2. Campaign Coupon Purchase

```
POST /api/campaign/{campaign_id}/buy
{
  "memberId": "member-uuid"
}
```

### 3. Manual Spend (Admin)

```
POST /api/points/spend
{
  "memberId": "member-uuid",
  "value": 100,
  "comment": "Manual adjustment"
}
```

---

## Transferring Points

Members can transfer points to other members:

```
POST /api/points/transfer/member
{
  "fromMemberId": "sender-uuid",
  "toMemberId": "receiver-uuid",
  "value": 50,
  "comment": "Gift"
}
```

**Rules:**
- Sender must have sufficient available (non-blocked) points
- Transfer creates two records: spend on sender, earn on receiver
- Minimum transfer amount can be configured in settings
- Transfers can be disabled entirely in settings

---

## Blocking and Unblocking

Points can be temporarily blocked (reserved) for pending operations:

### Block Points

```
POST /api/points/block
{
  "memberId": "member-uuid",
  "value": 500,
  "comment": "Reserved for pending reward redemption"
}
```

### Cancel Block (Unblock)

```
POST /api/points/transfer/{transfer_id}/cancel
```

### Complete Block (Convert to Spend)

When the pending operation is confirmed, the blocked points are
converted to a spend transaction.

---

## Expiry and Lifetime

Nayo supports configurable point expiry:

| Policy | Description |
|---|---|
| **No Expiry** | Points never expire |
| **Fixed Period** | Points expire X days after earning (e.g., 365 days) |
| **Activity-Based** | Points expire if no activity for X days |
| **Calendar-Based** | All points earned in a year expire at year-end |

### Configure Expiry

Set in the admin panel under Settings > Points Configuration:

```json
{
  "pointsExpiry": {
    "enabled": true,
    "policy": "fixed_period",
    "days": 365,
    "notifyBeforeDays": 30
  }
}
```

### Manual Expiry

```
POST /api/points/transfer/{transfer_id}/expire
```

### Check Expiring Points

```
GET /api/member/{member_id}/loyalty
```

Returns `expiringPoints` and `expiryDate` in the response.

---

## Multi-Wallet

Nayo supports multiple point wallets per member:

```
Member
  |
  +-- Standard Wallet (default)
  |     Balance: 1,500 points
  |     Expires: 2027-08-02
  |
  +-- Bonus Wallet
  |     Balance: 200 points
  |     Expires: 2026-12-31
  |
  +-- Referral Wallet
        Balance: 500 points
        Expires: No expiry
```

### Wallet Operations

- Earn rules can target specific wallets
- Spend operations draw from the wallet with nearest expiry first
- Admin can transfer between member wallets
- Each wallet has independent expiry and balance

---

## Earning Rules Configuration

Earning rules determine how points are awarded. Configure in the
admin panel or via API.

### Rule Types

| Type | Trigger | Example |
|---|---|---|
| **Transaction Value** | Per transaction total | 1 point per 100 UGX spent |
| **Product SKU** | Specific product purchased | 50 points per coffee |
| **Product Category** | Product category | 2x points on Electronics |
| **Custom Event** | Non-transaction event | 100 points for app install |
| **Referral** | Successful referral | 500 points per referral |
| **Birthday** | Member's birthday | 200 bonus points |
| **Anniversary** | Member registration date | 500 bonus points |
| **First Transaction** | Member's first purchase | 1,000 welcome points |
| **Milestone** | Reaching point threshold | 500 bonus at 5,000 points |

### Rule Configuration Example

```json
{
  "name": "Standard Earn Rate",
  "description": "1 point per 100 UGX spent",
  "type": "transaction_value",
  "active": true,
  "startAt": "2026-01-01T00:00:00+03:00",
  "endAt": null,
  "limit": {
    "active": false
  },
  "eventData": {
    "reward": {
      "type": "points",
      "formula": "Math.floor(transaction.summary.grossValue / 100)"
    },
    "conditions": [
      {
        "type": "transaction.value",
        "operator": ">=",
        "value": 1000
      }
    ]
  }
}
```

### Product-Specific Rule

```json
{
  "name": "Coffee Loyalty",
  "description": "50 points for every coffee purchased",
  "type": "product_sku",
  "active": true,
  "eventData": {
    "reward": {
      "type": "points",
      "formula": "50 * item.quantity"
    },
    "conditions": [
      {
        "type": "item.sku",
        "operator": "==",
        "value": "COFFEE-001"
      }
    ]
  }
}
```

### Custom Event Rule

```json
{
  "name": "App Install Bonus",
  "description": "100 points for installing the mobile app",
  "type": "custom_event",
  "active": true,
  "eventData": {
    "name": "app_installed",
    "reward": {
      "type": "points",
      "value": 100
    },
    "limit": {
      "active": true,
      "limit": 1,
      "limitPerUser": 1
    }
  }
}
```

---

## Points Calculation Examples

### Example 1: Simple Transaction

```
Transaction total: UGX 125,000
Earning rule: 1 point per 100 UGX

Points earned: floor(125,000 / 100) = 1,250 points
```

### Example 2: Multi-Rule Transaction

```
Transaction total: UGX 125,000
Items:
  - Samsung Phone: UGX 650,000 (Electronics)
  - Phone Case: UGX 30,000 (Accessories)
  - Charger: UGX 45,000 (Accessories)

Active rules:
  1. Standard: 1 point per 100 UGX on total
  2. Electronics bonus: 3x points on Electronics
  3. Accessories: 10 flat points per accessory item

Calculation:
  1. Standard: floor(725,000 / 100) = 7,250 points
  2. Electronics: floor(650,000 / 100) * 3 = 19,500 points (replaces standard for this item)
  3. Accessories: 10 * 2 items = 20 points

Total: 7,250 (standard on non-electronics) + 19,500 (electronics) + 20 (accessories)
     = 26,770 points
```

### Example 3: Tier Multiplier

```
Member tier: Gold (2x multiplier)
Transaction total: UGX 50,000
Base rate: 1 point per 100 UGX

Base points: floor(50,000 / 100) = 500
Tier bonus: 500 * 2 = 1,000 points
Total: 1,000 points
```

---

## API Reference

### Points Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/points` | List all point transfers |
| GET | `/api/points/transfer/{id}` | Get transfer details |
| POST | `/api/points/transfer` | Add/earn points |
| POST | `/api/points/spend` | Spend/deduct points |
| POST | `/api/points/block` | Block/reserve points |
| POST | `/api/points/transfer/{id}/cancel` | Cancel a transfer |
| POST | `/api/points/transfer/{id}/expire` | Expire a transfer |
| POST | `/api/points/transfer/{id}/activate` | Activate a pending transfer |
| POST | `/api/points/transfer/member` | Transfer between members |
| GET | `/api/points/histogram` | Points distribution histogram |
| PATCH | `/api/points/transfer/{id}` | Update transfer labels |

### Member Points Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/member/{id}/loyalty` | Get member loyalty status |
| GET | `/api/member/me/units` | Get logged member's units |

---

## Odoo Integration

### Syncing Transactions for Points

When a sale order is confirmed in Odoo, the transaction is sent to Nayo
and points are automatically calculated based on configured earning rules.

See `ODOO_INTEGRATION_GUIDE.md` for the full sync implementation.

### Displaying Points in Odoo

Add loyalty points display to the Odoo partner form:

```python
class ResPartner(models.Model):
    _inherit = 'res.partner'

    x_loyalty_points = fields.Integer('Loyalty Points', readonly=True)
    x_loyalty_tier = fields.Char('Loyalty Tier', readonly=True)
    x_loyalty_card_number = fields.Char('Loyalty Card Number')

    def action_refresh_loyalty(self):
        """Fetch latest loyalty status from Nayo."""
        self.ensure_one()
        nayo = self.env['nayo.sync']
        status = nayo.get_member_status(self)
        if status:
            self.write({
                'x_loyalty_points': status.get('points', 0),
                'x_loyalty_tier': status.get('level', ''),
            })
```

### Triggering Points from Odoo Events

```python
# Example: Award points when a customer leaves a review
def _on_review_created(self, review):
    nayo_url = self.env['ir.config_parameter'].sudo().get_param('nayo.api_url')
    api_key = self.env['ir.config_parameter'].sudo().get_param('nayo.api_key')

    partner = review.partner_id
    if partner.x_loyalty_card_number:
        requests.post(
            f"{nayo_url}/api/event",
            json={
                "name": "review_submitted",
                "memberId": partner.x_loyalty_card_number,
                "data": {
                    "product_id": review.product_id.id,
                    "rating": review.rating,
                    "odoo_review_id": review.id
                }
            },
            headers={"Authorization": f"Bearer {api_key}"}
        )
```

---

## Admin Panel Operations

### View Member Points History

In the admin panel:
1. Navigate to Members > Select member
2. Click "Points History" tab
3. View all earn, spend, transfer, and expiry events

### Manual Point Adjustment

1. Navigate to Members > Select member
2. Click "Add Points" or "Deduct Points"
3. Enter amount and reason
4. Confirm

### Bulk Point Operations

1. Navigate to Points > Bulk Actions
2. Select operation type (add, spend, expire)
3. Upload CSV with member IDs and amounts
4. Execute and monitor progress

### Points Reports

Available reports:
- **Points Summary** — Total earned, spent, expired, and current balance
- **Points by Period** — Daily/weekly/monthly points activity
- **Top Earners** — Members earning the most points
- **Expiry Forecast** — Points expiring in the next N days
- **Rule Performance** — Points awarded per earning rule
