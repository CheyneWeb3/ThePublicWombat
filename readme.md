Got it — here’s a tight, shill-first **user guide** for Golden Wombat plus a **contract-at-a-glance** (no code patches). I’ve called out the **rewards token update** feature and how you can expand it later.

# Golden Wombat (GWB) — Simple Guide

## Why hold $GWB? 🦡✨

* **Stable rewards:** Hold GWB, earn **USDC** automatically.
* **Clean tokenomics:** **6% in / 6% out** — **3% USDC rewards** to holders, **2% charity**, **1% marketing**.
* **Real impact:** Charity is **auto-split** between **Wombat** & **Forest** wallets.
* **Owner controls:** Sensible toggles for fees, limits, thresholds, and gas so ops stay smooth.

### Core facts

* **Name:** Golden Wombat
* **Symbol:** GWB
* **Supply:** **1,000,000,000** (1B)
* **Taxes:** 6% buy / 6% sell (1% Marketing, 2% Donations, 3% Rewards in **USDC**)
* **Donations:** Split across **two charity wallets** (Wombat + Forest)

---

## Quick start (owner flow)

1. **Set wallets** (marketing + two charities) and their **donation split** (e.g., 50/50).
2. **Choose rewards asset:** default is **USDC**; you can switch anytime.
3. (Optional) Tune **max wallet**, **swap threshold**, and **gas** for processing.
4. **Enable trading** and add liquidity.
5. Watch rewards accrue; holders can **auto-claim** or **manual claim**.

> Tip: For USDC rewards to work, your router needs a liquid **WETH↔USDC** pool.

---

# Contract at a Glance (main functions)

### Launch & Ops

* **`enableTrading()`** — Irreversible switch to allow non-owner transfers.
* **Pair/Router** — Pair is created against the router’s **WETH()** during deploy.

### Fees & Limits

* **`updateFees(mktBuy,mktSell,rewBuy,rewSell,donBuy,donSell)`**
  Caps: **buy/sell ≤ 8% each**; ensures your **6/6** schedule (1/3/2) stays within limits.
* **`updateTransferFee(uint256)`** — Wallet→wallet transfers only (max **5%**, default **0%**).
* **`setmaxWallet(uint256)`** — Anti-whale cap (min allowed = **0.1%** of supply).
* **`setSwapTriggerAmount(uint256)`** — Contract token threshold that triggers swap & distribute on sells.
* **`updateGasForProcessing(uint256)`** — Bounds-checked gas budget for the auto-claim loop.

### Donations with additional 50/50 splitter

* **`setDonationWallets(address wombat, address forest)`** — Set both charity wallets.
* **`setDonationSplitBps(uint256)`** — Basis-points to **Wombat** (remainder to **Forest**).
  Example: 5000 = 50% / 50%.

### Rewards / Dividends

* **`updatePayoutToken(address token)`** — **Change rewards asset** anytime.

  * `address(0)` = chain native (e.g., ETH/RBAT).
  * Any ERC-20 with a **WETH direct pool** works (USDC recommended).
* **`claim()`** — Holder claims rewards now.
* **`setAutoClaim(bool)`**, **`setReinvest(bool)`** — Holder preferences (auto loop / auto-reinvest if enabled).
* **`setDividendsPaused(bool)`** — Admin pause for distributions (claims resume later).
* **Minimums:**
  **`setMinimumTokenBalanceForAutoDividends(uint256)`**, **`setMinimumTokenBalanceForDividends(uint256)`** — Eligibility thresholds.

### Exclusions & Admin

* **`setExcludeFees(address,bool)`** — Fee exempt address.
* **`setExcludeDividends(address)` / `setIncludeDividends(address)`** — Remove/add address from rewards (syncs snapshot).
* **`transferAdmin(address)`** — Hand token ownership (sets sensible exclusions for the new owner).

### Monitoring / Reads

* **`getPayoutToken()`** — Current rewards asset.
* **`getTotalDividendsDistributed()`** — Lifetime distributed total.
* **`withdrawableDividendOf(address)`**, **`dividendTokenBalanceOf(address)`** — Per-holder visibility.
* **`getNumberOfDividendTokenHolders()`**, **`getLastProcessedIndex()`**, **`getAccountDividendsInfo(address)`** — Tracker status.

---

## Rewards Token Updates & Future Expansion

### Rewards token (today)

* **Switch on the fly** with `updatePayoutToken(address)` — default **USDC** for stable income.
* Uses a **simple two-hop path** `[WETH, TOKEN]` for payouts. Pick tokens with **direct WETH pools** to avoid failures.

### Easy future upgrades (tomorrow)

* **Flexible paths:** add multi-hop reward routes (e.g., `[WETH, USDbC, TOKEN]`) if your DEX needs it.
* **Multi-asset rewards mode:** rotate or split payouts across multiple stablecoins.
* **Dynamic donation routing:** allow **N** charity wallets with weighted BPS per wallet.
* **Ops safety:** add a **fee-schedule lock** post-launch, or time-locked changes via a multisig.
* **UX extras:** on-chain events for claims & donations to power dashboards and badges.

---

If you want this formatted as a one-pager for docs/website, I can drop it into a clean markdown (or React page) with your branding.

