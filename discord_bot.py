"""
Specter / Zenith — Discord License Bot
Slash commands for key management + automatic role system.

ENV VARS (set in Discord bot host or .env):
  DISCORD_TOKEN       — Bot token from Discord Developer Portal
  API_URL             — License server URL (e.g. https://your-app.up.railway.app)
  ADMIN_SECRET        — Matches server.js ADMIN_SECRET
  ADMIN_ROLE_ID       — Discord role ID that can use admin commands (optional)
  DEFAULT_ROLE_NAME   — Role given to every new member (default: "Member")
  LOG_CHANNEL_ID      — Channel ID for key/role logs (optional)
"""

import os
import json
import aiohttp
import discord
from discord import app_commands

# ── Config ────────────────────────────────────────────────────────────

DISCORD_TOKEN     = os.getenv("DISCORD_TOKEN", "")
API_URL           = os.getenv("API_URL", "http://localhost:3000").rstrip("/")
ADMIN_SECRET      = os.getenv("ADMIN_SECRET", "change_this_secret_now")
ADMIN_ROLE_ID     = int(os.getenv("ADMIN_ROLE_ID", "0"))
DEFAULT_ROLE_NAME = os.getenv("DEFAULT_ROLE_NAME", "Member")
LOG_CHANNEL_ID    = int(os.getenv("LOG_CHANNEL_ID", "0"))

VALID_PLANS     = ["beta", "nightly", "specter"]
VALID_DURATIONS = ["lifetime", "1d", "7d", "14d", "30d", "90d"]

ROLE_CONFIG = {
    "Member":   {"color": 0x808080, "hoist": False, "position": "bottom"},
    "Specter":  {"color": 0x82C3FF, "hoist": True,  "position": "mid"},
    "Beta":     {"color": 0xC882FF, "hoist": True,  "position": "mid"},
    "Nightly":  {"color": 0xFF82A0, "hoist": True,  "position": "mid"},
    "Customer": {"color": 0x60FF90, "hoist": True,  "position": "mid"},
    "Staff":    {"color": 0xFFC850, "hoist": True,  "position": "top"},
}

PLAN_TO_ROLE = {
    "specter":  "Specter",
    "beta":     "Beta",
    "nightly":  "Nightly",
}

# ── Bot setup ─────────────────────────────────────────────────────────

intents = discord.Intents.default()
intents.members = True
client  = discord.Client(intents=intents)
tree    = app_commands.CommandTree(client)


def is_admin(interaction: discord.Interaction) -> bool:
    if interaction.user.id == interaction.guild.owner_id:
        return True
    if ADMIN_ROLE_ID:
        return any(r.id == ADMIN_ROLE_ID for r in interaction.user.roles)
    return interaction.user.guild_permissions.administrator


async def api_post(path: str, data: dict) -> dict:
    async with aiohttp.ClientSession() as s:
        async with s.post(
            f"{API_URL}{path}",
            json=data,
            headers={"x-admin-secret": ADMIN_SECRET},
        ) as r:
            return {"status": r.status, **(await r.json())}


async def api_get(path: str) -> dict | list:
    async with aiohttp.ClientSession() as s:
        async with s.get(
            f"{API_URL}{path}",
            headers={"x-admin-secret": ADMIN_SECRET},
        ) as r:
            body = await r.json()
            if isinstance(body, list):
                return body
            return {"status": r.status, **body}


async def log_action(guild: discord.Guild, embed: discord.Embed):
    if not LOG_CHANNEL_ID:
        return
    ch = guild.get_channel(LOG_CHANNEL_ID)
    if ch and isinstance(ch, discord.TextChannel):
        try:
            await ch.send(embed=embed)
        except discord.Forbidden:
            pass


async def find_or_create_role(guild: discord.Guild, name: str) -> discord.Role | None:
    role = discord.utils.get(guild.roles, name=name)
    if role:
        return role
    cfg = ROLE_CONFIG.get(name, {"color": 0x808080, "hoist": False})
    try:
        role = await guild.create_role(
            name=name,
            color=discord.Color(cfg["color"]),
            hoist=cfg["hoist"],
            mentionable=False,
            reason=f"Auto-created by license bot",
        )
        return role
    except discord.Forbidden:
        return None


# ── Auto-role on join ─────────────────────────────────────────────────

@client.event
async def on_member_join(member: discord.Member):
    role = await find_or_create_role(member.guild, DEFAULT_ROLE_NAME)
    if not role:
        return
    try:
        await member.add_roles(role, reason="Auto-role on join")
    except discord.Forbidden:
        pass

    embed = discord.Embed(
        title="Member Joined",
        description=f"{member.mention} joined and got **{role.name}** role.",
        color=0x82C3FF,
    )
    embed.set_thumbnail(url=member.display_avatar.url if member.display_avatar else "")
    await log_action(member.guild, embed)


# ── /setup_roles — create all roles at once ──────────────────────────

@tree.command(name="setup_roles", description="Create all license roles (Member, Specter, Beta, Nightly, Customer, Staff)")
async def setup_roles(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild
    created = []
    existed = []
    failed  = []

    for name, cfg in ROLE_CONFIG.items():
        existing = discord.utils.get(guild.roles, name=name)
        if existing:
            existed.append(name)
            continue
        try:
            await guild.create_role(
                name=name,
                color=discord.Color(cfg["color"]),
                hoist=cfg["hoist"],
                mentionable=False,
                reason=f"Setup by {interaction.user}",
            )
            created.append(name)
        except discord.Forbidden:
            failed.append(name)

    embed = discord.Embed(title="Role Setup", color=0x60FF90)
    if created:
        embed.add_field(name="Created", value=", ".join(f"**{r}**" for r in created), inline=False)
    if existed:
        embed.add_field(name="Already exist", value=", ".join(f"**{r}**" for r in existed), inline=False)
    if failed:
        embed.add_field(name="Failed (missing perms)", value=", ".join(f"**{r}**" for r in failed), inline=False)

    desc_lines = [
        "**Role hierarchy (drag in Server Settings > Roles):**",
        "",
        "```",
        "  Staff      — admin / moderator",
        "  Nightly    — nightly plan users",
        "  Beta       — beta plan users",
        "  Specter    — specter plan users",
        "  Customer   — any redeemed key",
        "  Member     — auto-assigned on join",
        "  @everyone  — no access",
        "```",
        "",
        "**Recommended channel permissions:**",
        "- `#general` — Member+",
        "- `#support` — Customer+",
        "- `#specter` — Specter only",
        "- `#beta` — Beta only",
        "- `#nightly` — Nightly only",
        "- `#staff` — Staff only",
    ]
    embed.description = "\n".join(desc_lines)
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /setup_channels — create plan-locked channels ────────────────────

@tree.command(name="setup_channels", description="Create role-locked channels for each plan + general/support/staff")
async def setup_channels(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild

    member_role   = await find_or_create_role(guild, "Member")
    customer_role = await find_or_create_role(guild, "Customer")
    staff_role    = await find_or_create_role(guild, "Staff")
    plan_roles    = {}
    for plan, rname in PLAN_TO_ROLE.items():
        plan_roles[plan] = await find_or_create_role(guild, rname)

    channels_spec = [
        {
            "name": "general",
            "allow": [member_role],
            "topic": "General chat for all members",
        },
        {
            "name": "support",
            "allow": [customer_role, staff_role],
            "topic": "Customer support",
        },
        {
            "name": "specter",
            "allow": [plan_roles.get("specter"), staff_role],
            "topic": "Specter users only",
        },
        {
            "name": "beta",
            "allow": [plan_roles.get("beta"), staff_role],
            "topic": "Beta users only",
        },
        {
            "name": "nightly",
            "allow": [plan_roles.get("nightly"), staff_role],
            "topic": "Nightly users only",
        },
        {
            "name": "staff",
            "allow": [staff_role],
            "topic": "Staff only",
        },
    ]

    created = []
    existed = []
    for spec in channels_spec:
        if discord.utils.get(guild.text_channels, name=spec["name"]):
            existed.append(f"#{spec['name']}")
            continue

        overwrites = {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
        }
        for role in spec["allow"]:
            if role:
                overwrites[role] = discord.PermissionOverwrite(
                    view_channel=True,
                    send_messages=True,
                    read_message_history=True,
                )

        try:
            await guild.create_text_channel(
                name=spec["name"],
                topic=spec["topic"],
                overwrites=overwrites,
                reason=f"Setup by {interaction.user}",
            )
            created.append(f"#{spec['name']}")
        except discord.Forbidden:
            pass

    embed = discord.Embed(title="Channel Setup", color=0x60FF90)
    if created:
        embed.add_field(name="Created", value="\n".join(created), inline=False)
    if existed:
        embed.add_field(name="Already exist", value="\n".join(existed), inline=False)
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /give_role — manual role assign ──────────────────────────────────

@tree.command(name="give_role", description="Give a role to a user")
@app_commands.describe(user="Target user", role_name="Role to give")
@app_commands.choices(
    role_name=[app_commands.Choice(name=r, value=r) for r in ROLE_CONFIG],
)
async def give_role(interaction: discord.Interaction, user: discord.Member, role_name: str):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    role = await find_or_create_role(interaction.guild, role_name)
    if not role:
        await interaction.followup.send("Could not find/create role.", ephemeral=True)
        return

    try:
        await user.add_roles(role, reason=f"Given by {interaction.user}")
        embed = discord.Embed(title="Role Given", color=0x60FF90)
        embed.description = f"{user.mention} got **{role_name}**"
        await interaction.followup.send(embed=embed, ephemeral=True)
        await log_action(interaction.guild, embed)
    except discord.Forbidden:
        await interaction.followup.send("Missing permissions to assign role.", ephemeral=True)


# ── /remove_role — manual role remove ────────────────────────────────

@tree.command(name="remove_role", description="Remove a role from a user")
@app_commands.describe(user="Target user", role_name="Role to remove")
@app_commands.choices(
    role_name=[app_commands.Choice(name=r, value=r) for r in ROLE_CONFIG],
)
async def remove_role(interaction: discord.Interaction, user: discord.Member, role_name: str):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    role = discord.utils.get(interaction.guild.roles, name=role_name)
    if not role:
        await interaction.followup.send(f"Role '{role_name}' not found.", ephemeral=True)
        return

    try:
        await user.remove_roles(role, reason=f"Removed by {interaction.user}")
        embed = discord.Embed(title="Role Removed", color=0xFF6060)
        embed.description = f"{user.mention} lost **{role_name}**"
        await interaction.followup.send(embed=embed, ephemeral=True)
        await log_action(interaction.guild, embed)
    except discord.Forbidden:
        await interaction.followup.send("Missing permissions to remove role.", ephemeral=True)


# ── /key create ───────────────────────────────────────────────────────

@tree.command(name="key_create", description="Generate a new license key")
@app_commands.describe(
    plan="Plan tier",
    duration="How long the key lasts",
    note="Who this key is for",
)
@app_commands.choices(
    plan=[app_commands.Choice(name=p, value=p) for p in VALID_PLANS],
    duration=[app_commands.Choice(name=d, value=d) for d in VALID_DURATIONS],
)
async def key_create(
    interaction: discord.Interaction,
    plan: str,
    duration: str = "lifetime",
    note: str = "",
):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/create", {"plan": plan, "duration": duration, "note": note})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("key"):
        exp = res.get("expires_at")
        exp_str = "lifetime" if not exp else f"<t:{int(exp/1000)}:R>"
        embed = discord.Embed(title="Key Created", color=0x60FF90)
        embed.add_field(name="Key",      value=f"```{res['key']}```", inline=False)
        embed.add_field(name="Plan",     value=plan,    inline=True)
        embed.add_field(name="Duration", value=exp_str, inline=True)
        if note:
            embed.add_field(name="Note", value=note, inline=True)
        await interaction.followup.send(embed=embed, ephemeral=True)

        log_embed = discord.Embed(title="Key Created", color=0x60FF90)
        log_embed.add_field(name="Plan", value=plan, inline=True)
        log_embed.add_field(name="Duration", value=exp_str, inline=True)
        log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
        if note:
            log_embed.add_field(name="Note", value=note, inline=True)
        await log_action(interaction.guild, log_embed)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key revoke ───────────────────────────────────────────────────────

@tree.command(name="key_revoke", description="Revoke a license key and optionally remove user's role")
@app_commands.describe(key="The license key to revoke", user="User to remove plan role from (optional)")
async def key_revoke(interaction: discord.Interaction, key: str, user: discord.Member = None):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/revoke", {"key": key})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("revoked"):
        embed = discord.Embed(title="Key Revoked", color=0xFF6060)
        embed.add_field(name="Key", value=f"```{key}```", inline=False)

        if user:
            removed_roles = []
            for rname in list(PLAN_TO_ROLE.values()) + ["Customer"]:
                role = discord.utils.get(interaction.guild.roles, name=rname)
                if role and role in user.roles:
                    try:
                        await user.remove_roles(role, reason=f"Key revoked by {interaction.user}")
                        removed_roles.append(rname)
                    except discord.Forbidden:
                        pass
            if removed_roles:
                embed.add_field(name="Roles removed", value=f"{user.mention}: {', '.join(removed_roles)}", inline=False)

        await interaction.followup.send(embed=embed, ephemeral=True)

        log_embed = discord.Embed(title="Key Revoked", color=0xFF6060)
        log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
        if user:
            log_embed.add_field(name="User", value=user.mention, inline=True)
        await log_action(interaction.guild, log_embed)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key reset_hwid ──────────────────────────────────────────────────

@tree.command(name="key_reset_hwid", description="Reset HWID lock on a key")
@app_commands.describe(key="The license key to reset HWID for")
async def key_reset_hwid(interaction: discord.Interaction, key: str):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/reset_hwid", {"key": key})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("reset"):
        embed = discord.Embed(title="HWID Reset", color=0xFFC850)
        embed.add_field(name="Key", value=f"```{key}```", inline=False)
        embed.description = "Key can now be activated on a new machine."
        await interaction.followup.send(embed=embed, ephemeral=True)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key list ─────────────────────────────────────────────────────────

@tree.command(name="key_list", description="List all license keys")
@app_commands.describe(plan="Filter by plan (optional)")
@app_commands.choices(
    plan=[app_commands.Choice(name=p, value=p) for p in VALID_PLANS],
)
async def key_list(interaction: discord.Interaction, plan: str = ""):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if isinstance(keys, dict) and keys.get("status") == 403:
        await interaction.followup.send("Auth failed — check ADMIN_SECRET.", ephemeral=True)
        return

    if plan:
        keys = [k for k in keys if k.get("plan") == plan]

    if not keys:
        await interaction.followup.send("No keys found.", ephemeral=True)
        return

    chunks = []
    current = ""
    for k in keys:
        if k.get("revoked"):
            status = "REVOKED"
        elif k.get("expired"):
            status = "EXPIRED"
        elif k.get("hwid_locked"):
            status = "ACTIVE"
        else:
            status = "UNUSED"

        line = f"`{k['key']}` | **{k['plan']}** | {status}"
        if k.get("note"):
            line += f" | {k['note']}"
        line += "\n"

        if len(current) + len(line) > 3900:
            chunks.append(current)
            current = line
        else:
            current += line

    if current:
        chunks.append(current)

    for i, chunk in enumerate(chunks):
        embed = discord.Embed(
            title=f"License Keys ({len(keys)} total)" if i == 0 else "Keys (cont.)",
            description=chunk,
            color=0x82C3FF,
        )
        await interaction.followup.send(embed=embed, ephemeral=True)


# ── /key info ─────────────────────────────────────────────────────────

@tree.command(name="key_info", description="Show details for a specific key")
@app_commands.describe(key="The license key to look up")
async def key_info(interaction: discord.Interaction, key: str):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if isinstance(keys, dict):
        await interaction.followup.send(f"Error: {keys}", ephemeral=True)
        return

    found = next((k for k in keys if k["key"] == key), None)
    if not found:
        await interaction.followup.send(f"Key `{key}` not found.", ephemeral=True)
        return

    status = "REVOKED" if found.get("revoked") else "EXPIRED" if found.get("expired") else "ACTIVE" if found.get("hwid_locked") else "UNUSED"
    color  = 0xFF6060 if status in ("REVOKED","EXPIRED") else 0x60FF90 if status == "ACTIVE" else 0xC8C8C8

    exp = found.get("expires_at")
    exp_str = "Lifetime" if not exp else f"<t:{int(exp/1000)}:F>"

    embed = discord.Embed(title="Key Details", color=color)
    embed.add_field(name="Key",      value=f"```{found['key']}```", inline=False)
    embed.add_field(name="Plan",     value=found["plan"],   inline=True)
    embed.add_field(name="Status",   value=status,          inline=True)
    embed.add_field(name="Expires",  value=exp_str,         inline=True)
    embed.add_field(name="HWID",     value="Locked" if found.get("hwid_locked") else "Not set", inline=True)
    if found.get("note"):
        embed.add_field(name="Note", value=found["note"], inline=True)
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /redeem — user-facing key claim + auto role ──────────────────────

@tree.command(name="redeem", description="Claim your license key and get your role")
@app_commands.describe(key="Your license key")
async def redeem(interaction: discord.Interaction, key: str):
    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send("Server unreachable. Try again later.", ephemeral=True)
        return

    if isinstance(keys, dict):
        await interaction.followup.send("Server error.", ephemeral=True)
        return

    found = next((k for k in keys if k["key"] == key), None)
    if not found:
        await interaction.followup.send("Invalid key.", ephemeral=True)
        return

    if found.get("revoked"):
        await interaction.followup.send("This key has been revoked.", ephemeral=True)
        return
    if found.get("expired"):
        await interaction.followup.send("This key has expired.", ephemeral=True)
        return

    plan = found["plan"]
    exp  = found.get("expires_at")
    exp_str = "Lifetime" if not exp else f"<t:{int(exp/1000)}:R>"

    guild  = interaction.guild
    member = interaction.user

    assigned_roles = []

    customer_role = await find_or_create_role(guild, "Customer")
    if customer_role and customer_role not in member.roles:
        try:
            await member.add_roles(customer_role, reason=f"Redeemed key: {plan}")
            assigned_roles.append("Customer")
        except discord.Forbidden:
            pass

    plan_role_name = PLAN_TO_ROLE.get(plan)
    if plan_role_name:
        plan_role = await find_or_create_role(guild, plan_role_name)
        if plan_role and plan_role not in member.roles:
            try:
                await member.add_roles(plan_role, reason=f"Redeemed key: {plan}")
                assigned_roles.append(plan_role_name)
            except discord.Forbidden:
                pass

    embed = discord.Embed(title="Key Redeemed!", color=0x60FF90)
    embed.add_field(name="Key",      value=f"||{key}||",  inline=False)
    embed.add_field(name="Plan",     value=plan,           inline=True)
    embed.add_field(name="Expires",  value=exp_str,        inline=True)
    embed.add_field(name="Status",   value="Locked" if found.get("hwid_locked") else "Ready to activate", inline=True)
    if assigned_roles:
        embed.add_field(name="Roles given", value=", ".join(f"**{r}**" for r in assigned_roles), inline=False)
    embed.add_field(
        name="How to use",
        value=(
            "1. Open gamesense and load the loader\n"
            "2. Go to **AA > Anti-aimbot angles**\n"
            "3. Paste your key, pick a username & password\n"
            "4. Click **Register** (first time) or **Login**\n"
            "5. Your HWID locks on first use"
        ),
        inline=False,
    )
    await interaction.followup.send(embed=embed, ephemeral=True)

    log_embed = discord.Embed(title="Key Redeemed", color=0x60FF90)
    log_embed.add_field(name="User", value=member.mention, inline=True)
    log_embed.add_field(name="Plan", value=plan, inline=True)
    if assigned_roles:
        log_embed.add_field(name="Roles", value=", ".join(assigned_roles), inline=True)
    await log_action(guild, log_embed)


# ── Events ────────────────────────────────────────────────────────────

@client.event
async def on_ready():
    await tree.sync()
    print(f"Bot online: {client.user}  |  Guilds: {len(client.guilds)}")
    print(f"API: {API_URL}")
    print(f"Default role: {DEFAULT_ROLE_NAME}")


# ── Run ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if not DISCORD_TOKEN:
        print("ERROR: Set DISCORD_TOKEN environment variable.")
        raise SystemExit(1)
    client.run(DISCORD_TOKEN)
