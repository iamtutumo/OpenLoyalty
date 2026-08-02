# Multi-Product Transaction Examples for Nayo

This document provides examples of how to register multi-product
transactions with the Nayo loyalty API. These examples cover common
scenarios for standalone integrations and Odoo-based integrations.

---

## Basic API Endpoint

```
POST /api/transaction
Content-Type: application/json
Authorization: Bearer <token>
```

---

## Example 1: Simple Single-Item Purchase

A customer buys one product at a POS terminal.

```json
{
  "documentNumber": "POS/2026/0001",
  "documentType": "sell",
  "purchaseDate": "2026-08-02T10:30:00+03:00",
  "purchasePlace": "Kampala Central Store",
  "customerLoyaltyCardNumber": "LOY-2026-001",
  "posId": "pos-kampala-01",
  "items": [
    {
      "sku": "COFFEE-001",
      "name": "Cappuccino Large",
      "quantity": 1,
      "grossValue": 8000,
      "category": "Beverages"
    }
  ],
  "summary": {
    "grossValue": 8000
  }
}
```

**Points earned:** Based on earning rules configured in Nayo
(e.g., 1 point per UGX 1,000 spent = 8 points)

---

## Example 2: Multi-Item Purchase (Retail)

A customer buys several products across different categories.

```json
{
  "documentNumber": "SO/2026/0142",
  "documentType": "sell",
  "purchaseDate": "2026-08-02T14:15:00+03:00",
  "purchasePlace": "Ntinda Branch",
  "customerLoyaltyCardNumber": "LOY-2026-055",
  "posId": "pos-ntinda-01",
  "items": [
    {
      "sku": "ELEC-PHONE-001",
      "name": "Samsung Galaxy A15",
      "quantity": 1,
      "grossValue": 650000,
      "category": "Electronics",
      "maker": "Samsung",
      "labels": {
        "color": "black",
        "storage": "128GB"
      }
    },
    {
      "sku": "ACC-CASE-010",
      "name": "Phone Case - Clear",
      "quantity": 2,
      "grossValue": 30000,
      "category": "Accessories"
    },
    {
      "sku": "ACC-CHARGER-005",
      "name": "USB-C Fast Charger 65W",
      "quantity": 1,
      "grossValue": 45000,
      "category": "Accessories",
      "maker": "Anker"
    }
  ],
  "summary": {
    "grossValue": 725000
  }
}
```

---

## Example 3: Odoo Sales Order Sync

Transaction synced from an Odoo Sales Order with multiple order lines.

```json
{
  "documentNumber": "S00142",
  "documentType": "sell",
  "purchaseDate": "2026-08-02T09:00:00+03:00",
  "purchasePlace": "Online Store",
  "customerLoyaltyCardNumber": "LOY-2026-100",
  "items": [
    {
      "sku": "CONS-SERVICE-01",
      "name": "Monthly Subscription - Premium",
      "quantity": 1,
      "grossValue": 150000,
      "category": "Services",
      "labels": {
        "odoo_product_id": "42",
        "odoo_sale_line_id": "891"
      }
    },
    {
      "sku": "CONS-ADDON-01",
      "name": "Extra Storage 100GB",
      "quantity": 1,
      "grossValue": 25000,
      "category": "Services",
      "labels": {
        "odoo_product_id": "55",
        "odoo_sale_line_id": "892"
      }
    },
    {
      "sku": "CONS-SUPPORT-01",
      "name": "Priority Support Add-on",
      "quantity": 1,
      "grossValue": 50000,
      "category": "Services",
      "labels": {
        "odoo_product_id": "60",
        "odoo_sale_line_id": "893"
      }
    }
  ],
  "summary": {
    "grossValue": 225000
  },
  "labels": {
    "odoo_sale_order_id": "142",
    "odoo_partner_id": "33",
    "source": "odoo"
  }
}
```

---

## Example 4: Odoo POS Order (Restaurant / QSR)

A restaurant order from Odoo POS with multiple items and a tip.

```json
{
  "documentNumber": "POS/Order/0042",
  "documentType": "sell",
  "purchaseDate": "2026-08-02T19:30:00+03:00",
  "purchasePlace": "Kololo Restaurant",
  "customerLoyaltyCardNumber": "LOY-2026-077",
  "posId": "pos-kololo-restaurant",
  "items": [
    {
      "sku": "FOOD-MAIN-010",
      "name": "Grilled Tilapia with Chips",
      "quantity": 2,
      "grossValue": 70000,
      "category": "Main Course"
    },
    {
      "sku": "FOOD-START-005",
      "name": "Samosa Plate (4 pcs)",
      "quantity": 1,
      "grossValue": 15000,
      "category": "Starters"
    },
    {
      "sku": "BEV-JUICE-003",
      "name": "Fresh Passion Fruit Juice",
      "quantity": 3,
      "grossValue": 24000,
      "category": "Beverages"
    },
    {
      "sku": "FOOD-DESSERT-002",
      "name": "Mandazi (6 pcs)",
      "quantity": 1,
      "grossValue": 6000,
      "category": "Desserts"
    }
  ],
  "summary": {
    "grossValue": 115000
  },
  "labels": {
    "odoo_pos_order_id": "42",
    "odoo_pos_config_id": "3",
    "table_number": "7",
    "source": "odoo_pos"
  }
}
```

---

## Example 5: Refund / Return Transaction

A customer returns items. Use `documentType: "return"` and negative values.

```json
{
  "documentNumber": "RET/2026/0012",
  "documentType": "return",
  "purchaseDate": "2026-08-02T16:00:00+03:00",
  "purchasePlace": "Kampala Central Store",
  "customerLoyaltyCardNumber": "LOY-2026-001",
  "posId": "pos-kampala-01",
  "revisedDocument": "POS/2026/0001",
  "items": [
    {
      "sku": "COFFEE-001",
      "name": "Cappuccino Large",
      "quantity": 1,
      "grossValue": 8000,
      "category": "Beverages"
    }
  ],
  "summary": {
    "grossValue": 8000
  }
}
```

**Effect:** Points earned from the original transaction are reversed.

---

## Example 6: B2B Bulk Order (Odoo Invoice)

A bulk order from a business customer synced from Odoo invoicing.

```json
{
  "documentNumber": "INV/2026/0089",
  "documentType": "sell",
  "purchaseDate": "2026-08-01T11:00:00+03:00",
  "purchasePlace": "B2B Portal",
  "customerLoyaltyCardNumber": "LOY-B2B-010",
  "items": [
    {
      "sku": "BULK-PAPER-A4",
      "name": "A4 Paper Ream (500 sheets)",
      "quantity": 50,
      "grossValue": 750000,
      "category": "Office Supplies",
      "labels": {
        "odoo_product_id": "101",
        "odoo_invoice_line_id": "2001"
      }
    },
    {
      "sku": "BULK-TONER-HP",
      "name": "HP LaserJet Toner Cartridge",
      "quantity": 10,
      "grossValue": 1200000,
      "category": "Office Supplies",
      "maker": "HP",
      "labels": {
        "odoo_product_id": "105",
        "odoo_invoice_line_id": "2002"
      }
    },
    {
      "sku": "BULK-CHAIR-EXEC",
      "name": "Executive Office Chair",
      "quantity": 5,
      "grossValue": 2500000,
      "category": "Furniture",
      "labels": {
        "odoo_product_id": "110",
        "odoo_invoice_line_id": "2003"
      }
    }
  ],
  "summary": {
    "grossValue": 4450000
  },
  "labels": {
    "odoo_invoice_id": "89",
    "odoo_partner_id": "15",
    "payment_terms": "net_30",
    "source": "odoo_invoice"
  }
}
```

---

## Earning Rules for Multi-Product Transactions

Nayo evaluates earning rules against each line item. Configure rules
in the admin panel to handle different scenarios:

### Rule: Points per Amount Spent

```
Trigger: Transaction registered
Formula: SUM of all items grossValue * 0.01
Result: 1 point per UGX 100 spent
```

### Rule: Category Bonus

```
Trigger: Transaction contains item with category "Electronics"
Formula: item.grossValue * 0.05
Result: 5x bonus points on electronics purchases
```

### Rule: Quantity Milestone

```
Trigger: Transaction contains item with quantity >= 10
Formula: 500 bonus points
Result: Bulk purchase bonus
```

### Rule: Product-Specific Reward

```
Trigger: Transaction contains item with SKU "COFFEE-001"
Formula: 20 points per unit
Result: Bonus points on every coffee purchased
```

### Rule: First Purchase Welcome

```
Trigger: Member's first transaction
Formula: 1000 points flat
Result: Welcome bonus on first transaction
```

---

## Python Helper for Odoo Integration

```python
import requests
from datetime import datetime

class NayoTransactionBuilder:
    """Helper to build Nayo transactions from Odoo sale orders."""

    def __init__(self, nayo_url, api_key):
        self.nayo_url = nayo_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

    def from_odoo_sale_order(self, order):
        """Convert an Odoo sale.order record to a Nayo transaction payload."""
        items = []
        for line in order.order_line:
            items.append({
                "sku": line.product_id.default_code or f"PROD-{line.product_id.id}",
                "name": line.product_id.name,
                "quantity": line.product_uom_qty,
                "grossValue": line.price_total,
                "category": line.product_id.categ_id.name or "General",
                "maker": (
                    line.product_id.product_brand_id.name
                    if hasattr(line.product_id, "product_brand_id")
                    else None
                ),
                "labels": {
                    "odoo_product_id": str(line.product_id.id),
                    "odoo_sale_line_id": str(line.id),
                },
            })

        partner = order.partner_id
        return {
            "documentNumber": order.name,
            "documentType": "sell",
            "purchaseDate": order.date_order.isoformat(),
            "purchasePlace": order.team_id.name if order.team_id else "Online",
            "customerLoyaltyCardNumber": getattr(partner, "loyalty_card_number", None),
            "items": items,
            "summary": {"grossValue": order.amount_total},
            "labels": {
                "odoo_sale_order_id": str(order.id),
                "odoo_partner_id": str(partner.id),
                "source": "odoo",
            },
        }

    def from_odoo_pos_order(self, pos_order):
        """Convert an Odoo pos.order record to a Nayo transaction payload."""
        items = []
        for line in pos_order.lines:
            items.append({
                "sku": line.product_id.default_code or f"PROD-{line.product_id.id}",
                "name": line.product_id.name,
                "quantity": line.qty,
                "grossValue": line.price_subtotal_incl,
                "category": line.product_id.pos_categ_id.name if line.product_id.pos_categ_id else "General",
                "labels": {
                    "odoo_product_id": str(line.product_id.id),
                    "odoo_pos_line_id": str(line.id),
                },
            })

        partner = pos_order.partner_id
        return {
            "documentNumber": pos_order.pos_reference or pos_order.name,
            "documentType": "sell",
            "purchaseDate": pos_order.date_order.isoformat(),
            "purchasePlace": pos_order.config_id.name,
            "customerLoyaltyCardNumber": (
                partner.loyalty_card_number if partner else None
            ),
            "posId": f"pos-{pos_order.config_id.id}",
            "items": items,
            "summary": {"grossValue": pos_order.amount_total},
            "labels": {
                "odoo_pos_order_id": str(pos_order.id),
                "source": "odoo_pos",
            },
        }

    def submit(self, payload):
        """Submit the transaction to Nayo API."""
        response = requests.post(
            f"{self.nayo_url}/api/transaction",
            json=payload,
            headers=self.headers,
        )
        response.raise_for_status()
        return response.json()
```
