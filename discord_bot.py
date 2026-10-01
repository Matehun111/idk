"""
Specter / Zenith — Discord License Bot
Slash commands for key management via the license server API.

ENV VARS (set in Discord bot host or .env):
  DISCORD_TOKEN       — Bot token from Discord Developer Portal
  API_URL             — License server URL (e.g. https://your-app.up.railway.app)
  ADMIN_SECRET        — Matches server.js ADMIN_SECRET
  ADMIN_ROLE_ID       — Discord role ID that can use admin commands (optional, defaults to server owner)
"""

import os
import datetime
import aiohttp
import discord
from discord import app_commands

# ── Config ────────────────────────────────────────────────────────────

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", "")
API_URL       = os.getenv("API_URL", "http://localhost:3000").rstrip("/")
ADMIN_SECRET  = os.getenv("ADMIN_SECRET", "change_this_secret_now")
ADMIN_ROLE_ID = int(os.getenv("ADMIN_ROLE_ID", "0"))

VALID_PLANS     = ["beta", "nightly", "specter"]
VALID_DURATIONS = ["lifetime", "1d", "7d", "14d", "30d", "90d"]

# ── Bot setup ─────────────────────────────────────────────────────────

intents = discord.Intents.default()
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
        embed = discord.Embed(
            title="Key Created",
            color=0x60FF90,
        )
        embed.add_field(name="Key",      value=f"```{res['key']}```", inline=False)
        embed.add_field(name="Plan",     value=plan,    inline=True)
        embed.add_field(name="Duration", value=exp_str, inline=True)
        if note:
            embed.add_field(name="Note", value=note, inline=True)
        await interaction.followup.send(embed=embed, ephemeral=True)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key revoke ───────────────────────────────────────────────────────

@tree.command(name="key_revoke", description="Revoke a license key")
@app_commands.describe(key="The license key to revoke")
async def key_revoke(interaction: discord.Interaction, key: str):
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
        await interaction.followup.send(embed=embed, ephemeral=True)
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
        status = ""
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
            title=f"License Keys ({len(keys)} total)" if i == 0 else f"Keys (cont.)",
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


# ── /redeem — user-facing key claim ──────────────────────────────────

@tree.command(name="redeem", description="Claim your license key and get instructions")
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

    embed = discord.Embed(title="Key Redeemed!", color=0x60FF90)
    embed.add_field(name="Key",      value=f"||{key}||",  inline=False)
    embed.add_field(name="Plan",     value=plan,           inline=True)
    embed.add_field(name="Expires",  value=exp_str,        inline=True)
    embed.add_field(name="Status",   value="Locked" if found.get("hwid_locked") else "Ready to activate", inline=True)
    embed.add_field(
        name="How to use",
        value=(
            "1. Open gamesense and load `specter_loader`\n"
            "2. Go to **AA > Anti-aimbot angles**\n"
            "3. Paste your key, pick a username & password\n"
            "4. Click **Register** (first time) or **Login**\n"
            "5. Your HWID locks on first use"
        ),
        inline=False,
    )
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── Events ────────────────────────────────────────────────────────────

@client.event
async def on_ready():
    await tree.sync()
    print(f"Bot online: {client.user}  |  Guilds: {len(client.guilds)}")
    print(f"API: {API_URL}")


# ── Run ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if not DISCORD_TOKEN:
        print("ERROR: Set DISCORD_TOKEN environment variable.")
        raise SystemExit(1)
    client.run(DISCORD_TOKEN)
