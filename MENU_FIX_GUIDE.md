# Odoo Menu Fix Guide for Nayo Integration

This guide addresses common menu-related issues that arise when integrating
Nayo with Odoo. The Nayo loyalty features are accessed through custom Odoo
menus added via a connector module.

---

## Common Issues and Fixes

### 1. Nayo Menu Not Visible After Module Installation

**Symptoms:**
- The Nayo Loyalty menu does not appear in the Odoo main navigation
- No error messages in the Odoo log

**Fix:**

1. Update the module list in Odoo:
   - Settings > Technical > Update Apps List
   - Click "Update"

2. Verify module is installed:
   - Settings > Apps > Search for "nayo_loyalty"
   - Confirm status shows "Installed"

3. Check user access rights:
   - Settings > Users & Companies > Users
   - Select the user
   - Under "Nayo Loyalty" section, ensure a role is assigned:
     - `Nayo Loyalty / Manager` (full access)
     - `Nayo Loyalty / User` (limited access)

4. Clear browser cache and hard-reload (Ctrl+Shift+R)

5. If still not visible, run from Odoo shell:

```python
# Open Odoo shell
# ./odoo-bin shell -d your_database

env['ir.ui.menu'].search([('name', 'ilike', 'nayo')]).mapped('name')
# If empty, the menus were not created. Upgrade the module:
env['ir.module.module'].search([('name', '=', 'nayo_loyalty')]).button_upgrade()
env.cr.commit()
```

---

### 2. Submenu Items Missing or in Wrong Order

**Symptoms:**
- Some Nayo submenus are missing
- Menu items appear in wrong order

**Fix:**

Check the module's `views/menu_views.xml` file. Ensure each menu item has
correct `parent` and `sequence` attributes:

```xml
<!-- Top-level menu -->
<menuitem id="menu_nayo_root"
    name="Nayo Loyalty"
    web_icon="nayo_loyalty,static/description/icon.png"
    sequence="50"/>

<!-- Category menus -->
<menuitem id="menu_nayo_config"
    name="Configuration"
    parent="menu_nayo_root"
    sequence="100"/>

<menuitem id="menu_nayo_operations"
    name="Operations"
    parent="menu_nayo_root"
    sequence="10"/>

<menuitem id="menu_nayo_reporting"
    name="Reporting"
    parent="menu_nayo_root"
    sequence="90"/>

<!-- Sub-menus -->
<menuitem id="menu_nayo_sync"
    name="Sync Members"
    parent="menu_nayo_operations"
    action="action_nayo_sync"
    sequence="10"/>

<menuitem id="menu_nayo_transactions"
    name="Transactions"
    parent="menu_nayo_operations"
    action="action_nayo_transactions"
    sequence="20"/>
```

After fixing, upgrade the module:

```bash
./odoo-bin -d your_database -u nayo_loyalty --stop-after-init
```

---

### 3. Menu Action Returns "Action Does Not Exist" Error

**Symptoms:**
- Clicking a Nayo menu item shows an error
- Error: "Action does not exist" or "View not found"

**Fix:**

1. Verify the action XML ID matches between menu and action definitions:

```xml
<!-- Action definition -->
<record id="action_nayo_members" model="ir.actions.act_window">
    <field name="name">Members</field>
    <field name="res_model">nayo.member</field>
    <field name="view_mode">tree,form</field>
</record>

<!-- Menu must reference the same ID -->
<menuitem id="menu_nayo_members"
    name="Members"
    parent="menu_nayo_operations"
    action="action_nayo_members"
    sequence="5"/>
```

2. If the action is defined in a different module, use the full XML ID:

```xml
<menuitem id="menu_nayo_partners"
    parent="menu_nayo_operations"
    action="base.action_partner_form"
    sequence="1"/>
```

---

### 4. Menu Visible Only for Admin, Not Other Users

**Symptoms:**
- Admin user can see all Nayo menus
- Other users cannot see any or some Nayo menus

**Fix:**

Menus in Odoo respect group-based visibility. Ensure security groups are
assigned correctly:

```xml
<!-- Menu with group restriction -->
<menuitem id="menu_nayo_config"
    name="Configuration"
    parent="menu_nayo_root"
    groups="nayo_loyalty.group_nayo_manager"
    sequence="100"/>
```

Check the security groups file (`security/security.xml`):

```xml
<record id="group_nayo_user" model="res.groups">
    <field name="name">User</field>
    <field name="category_id" ref="module_category_nayo"/>
</record>

<record id="group_nayo_manager" model="res.groups">
    <field name="name">Manager</field>
    <field name="category_id" ref="module_category_nayo"/>
    <field name="implied_ids" eval="[(4, ref('group_nayo_user'))]"/>
</record>
```

Assign groups to users:
- Settings > Users & Companies > Users > Select user
- Under "Nayo Loyalty" assign "User" or "Manager"

---

### 5. Menu Disappears After Odoo Upgrade

**Symptoms:**
- Nayo menus disappear after upgrading Odoo or another module

**Fix:**

1. Ensure the module has correct `__manifest__.py`:

```python
{
    'name': 'Nayo Loyalty Connector',
    'version': '17.0.1.0.0',
    'category': 'Sales/Loyalty',
    'depends': ['base', 'sale', 'point_of_sale'],
    'data': [
        'security/security.xml',
        'security/ir.model.access.csv',
        'views/menu_views.xml',
        'views/member_views.xml',
        'views/transaction_views.xml',
        'views/config_views.xml',
        'data/cron_data.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}
```

2. Ensure `data` files are listed in correct order (security before views)

3. Re-install the module:

```bash
./odoo-bin -d your_database -i nayo_loyalty --stop-after-init
```

---

### 6. Odoo 17+ Specific: Menu Icons Not Showing

In Odoo 17+, menu icons are specified differently:

```xml
<!-- Odoo 16 and below -->
<menuitem id="menu_nayo_root"
    name="Nayo Loyalty"
    web_icon="nayo_loyalty,static/description/icon.png"
    sequence="50"/>

<!-- Odoo 17+ - icon must be in static/description/icon.png -->
<!-- and the module must be listed as an "application" -->
<!-- in __manifest__.py: 'application': True -->
```

Ensure `static/description/icon.png` exists and is a valid PNG image
(recommended: 128x128 pixels).

---

## Diagnostic Commands

Run these from the Odoo shell to diagnose menu issues:

```python
# List all Nayo menus
menus = env['ir.ui.menu'].search([('name', 'ilike', 'nayo')])
for m in menus:
    print(f"  {m.id:5} | {m.complete_name:40} | groups: {[g.name for g in m.groups_id]}")

# Check if menus exist but are inactive
inactive = env['ir.ui.menu'].with_context(active_test=False).search([
    ('name', 'ilike', 'nayo'),
    ('active', '=', False)
])
print(f"Inactive Nayo menus: {len(inactive)}")

# Force activate inactive menus
inactive.write({'active': True})
env.cr.commit()

# Check user access to specific menu
user = env.user
menu = env.ref('nayo_loyalty.menu_nayo_root')
accessible = menu.with_user(user)._visible_menu_ids()
print(f"Menu {menu.name} visible to {user.name}: {menu.id in accessible}")
```

---

## Prevention

- Always test menu visibility with a non-admin user before deploying
- Include menu tests in your Odoo module's integration tests
- Pin your Nayo connector module version in production
- Document which Odoo groups map to which Nayo menu visibility
