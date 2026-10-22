"""Slack bot: /staffing <facility name or CCN> → staffing summary.

Phase 3 of the roadmap — this is a stub. It reads the same DuckDB warehouse
the Shiny app uses (read-only), so both always show the same numbers.

Run locally with Socket Mode:
    pip install -r bot/requirements.txt
    SLACK_BOT_TOKEN=... SLACK_APP_TOKEN=... python bot/app.py
"""

import os

import duckdb
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

DB_PATH = os.environ.get("PBJ_DB_PATH", "data/pbj.duckdb")

app = App(token=os.environ["SLACK_BOT_TOKEN"])

# Same rule as R/metrics.R: ratios are sum(hours) / sum(resident days).
FACILITY_SUMMARY_SQL = """
SELECT
    f.provnum,
    f.facility_name,
    f.city,
    f.state,
    sum(m.hrs_total) / nullif(sum(m.resident_days), 0)     AS total_hprd,
    sum(m.hrs_rn) / nullif(sum(m.resident_days), 0)        AS rn_hprd,
    sum(m.hrs_total_ctr) / nullif(sum(m.hrs_total), 0)     AS contract_share
FROM fct_facility_month m
JOIN dim_facility f USING (provnum)
WHERE f.provnum = $q OR f.facility_name ILIKE '%' || $q || '%'
GROUP BY ALL
ORDER BY f.facility_name
LIMIT 5
"""


def facility_summary(query: str) -> list[tuple]:
    with duckdb.connect(DB_PATH, read_only=True) as con:
        return con.execute(FACILITY_SUMMARY_SQL, {"q": query.strip()}).fetchall()


@app.command("/staffing")
def staffing(ack, command, respond):
    ack()
    rows = facility_summary(command["text"])
    if not rows:
        respond(f"No facility matched `{command['text']}`.")
        return

    # TODO: Block Kit layout, state comparison, xlsx attachment of monthly detail.
    lines = [
        f"*{name}* ({city}, {state}) — total HPRD {total:.2f}, "
        f"RN HPRD {rn:.2f}, contract share {ctr:.1%}"
        for _, name, city, state, total, rn, ctr in rows
    ]
    respond("\n".join(lines))


if __name__ == "__main__":
    SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"]).start()
