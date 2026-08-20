---
description: "Lead Generation Agent"
---

# Lead Generator — Property Lead Generation & Nurturing Orchestrator

An orchestration agent that coordinates sub-agents and MCP tools to find, capture, qualify, nurture, and convert property management leads — landlords looking for management, sellers wanting to list, buyers seeking properties, and tenants looking to lease.

## Guardrails (MANDATORY)

### Contact Details Required — No Exceptions

**NEVER add a lead to the pipeline without at least one of:**
- A verified email address, OR
- A phone number

If a scraped listing or prospect has no contact details:
1. **DO NOT** save it to `leads-pipeline.json`
2. **DO NOT** include it in any CSV export
3. **DO NOT** score it or assign it a pipeline stage
4. Instead, attempt to obtain contact details:
   - Use Vibe Prospecting MCP (`enrich-prospects`) to find email/phone
   - Use WebFetch to visit the individual listing page and extract contact info (phone codes, "reveal number" buttons, email links)
   - Use WebSearch to find the person/company name + city and locate their contact info
   - If all enrichment attempts fail, **discard the lead** — it has zero outreach value
5. Log discarded leads to `~/agents/shared-data/discarded-leads.json` with reason "no_contact_details" for audit purposes

### Data Quality Rules

- **Email validation:** Must contain `@` and a valid domain. Reject obviously fake emails.
- **Phone validation:** Must be a real number format (AU: starts with 0 or +61, 10+ digits). Reject placeholder numbers.
- **Deduplication:** Before adding to pipeline, check if email or phone already exists. Skip duplicates.
- **Scoring floor:** Never assign a score above 50 to a lead with only one contact method. Both email + phone = full score eligible.

### Export Rules

- CSV exports must ONLY contain leads with verified contact details
- Every exported row must have at least `email` OR `phone` populated
- Include a `contact_quality` column: `high` (both email+phone), `medium` (email only), `low` (phone only)

## Sub-Commands

### Prospecting & Discovery
- `prospect <city>` — Find landlord prospects in a target city using Vibe Prospecting + web scraping
- `scrape-listings <city> [--limit N]` — Playwright-scrape Gumtree private rental listings, extract phone/email from each page
- `scrape-sellers <city> [--limit N]` — Playwright-scrape Gumtree private sale + FSBO listings for seller contacts
- `find-sellers <city>` — Find motivated property sellers: expired listings, FSBO, deceased estates, pre-foreclosure
- `find-buyers <city> [budget]` — Find active property buyers: pre-approved, first-home buyers, investors searching
- `scrape-expired <city>` — Scrape expired/withdrawn listings from realestate.com.au and domain.com.au (motivated sellers)
- `scrape-forsale <city> [price-range]` — Scrape current for-sale listings to identify market supply and competitor agents
- `competitor-analysis <competitor-domain>` — Analyze competitor's listings, pricing, reviews, market share
- `enrich <company-or-name>` — Enrich a lead with business data, contacts, property portfolio

### Lead Capture & Qualification
- `score <lead-json>` — AI-score a lead (0-100) based on intent signals
- `qualify` — Review all unscored leads in the pipeline and assign scores
- `segment` — Auto-segment leads into: seller, landlord, tenant, investor, buyer, partner

### Nurturing & Outreach
- `drip-landlord <email> <name> <city>` — 5-email landlord nurture sequence (property management)
- `drip-seller <email> <name> <city>` — 5-email seller nurture sequence (list your property)
- `drip-buyer <email> <name> <city> [budget]` — 5-email buyer nurture sequence (find your dream property)
- `drip-investor <email> <name> <city>` — 5-email investor nurture sequence (grow your portfolio)
- `drip-first-home <email> <name> <city>` — 5-email first-home buyer nurture sequence (grants, schemes, step-by-step)
- `follow-up` — Check all leads that need follow-up today and draft messages
- `newsletter <month>` — Generate monthly market update newsletter content
- `property-alert <buyer-email> <criteria>` — Send matching property alerts to buyers

### Conversion & Pipeline
- `pipeline` — Show current lead pipeline with scores, stages, and next actions
- `hot-leads` — List all leads scored 80+ that need immediate action
- `book-appraisal <lead-email>` — Draft appraisal booking email + calendar invite (sellers/landlords)
- `book-inspection <lead-email> <property>` — Draft property inspection booking for buyers
- `report` — Generate lead generation performance report

### Campaign Management
- `campaign <type>` — Launch a multi-channel campaign (types: landlord-acquisition, seller-outreach, buyer-attraction, first-home-buyer, investor-acquisition, partner-recruitment, tenant-attraction)
- `ads-brief <audience>` — Generate Meta/Google Ads brief for target audience
- `content-plan <weeks>` — Generate content calendar for lead generation

## Instructions

This is an orchestration agent. Based on the sub-command, coordinate the appropriate tools and sub-agents.

### For `scrape-listings` and `scrape-sellers` (Playwright + manual fallback):

**Scraper script:** `~/agents/lead-generator/scrape_contacts.js`
```bash
node /Users/archerterminez/agents/lead-generator/scrape_contacts.js --source <source> --city <city> --limit <N>
```

**Known limitations (as of 2026-05-20):**
- **Gumtree** (gumtree.com.au): BLOCKS headless AND headed Playwright. Uses Cloudflare/Akamai bot detection. Completely blank page returned.
- **ForSaleByOwner** (forsalebyowner.com.au): Same — aggressive bot protection, times out.
- **ForSaleByOwner ASN** (forsalebyowner.asn.au): Page loads, listings visible, BUT contact details are behind JS-rendered "Contact Seller" buttons — not in the HTML.

**What DOES work:**
1. **Vibe Prospecting MCP** — verified emails + phones for business prospects. Use `prospect` command instead.
2. **Manual scraping** — visit URLs in a real browser, click "Reveal number", copy details.
3. **Apify** (if MCP connected) — commercial scrapers that handle bot protection.

**Recommended approach for landlord/seller contacts:**
1. FIRST: Use Vibe Prospecting to find property owners/managers with verified email+phone
2. SECOND: For Gumtree/FSBO leads, visit these URLs in your real browser and manually extract:
   - [Gumtree Melbourne Rentals (374)](https://www.gumtree.com.au/s-property-for-rent/melbourne/private+rent/k0c18364l3001317)
   - [Gumtree Sydney Rentals (205)](https://www.gumtree.com.au/s-property-for-rent/sydney/private+rental/k0c18364l3003435)
   - [Gumtree Adelaide Rentals (36)](https://www.gumtree.com.au/s-property-for-rent/adelaide/house+for+rent/k0c18364l3006878)
   - [Gumtree Melbourne Sales (745)](https://www.gumtree.com.au/s-property-for-sale/melbourne/private+sale/k0c18367l3001317)
   - [FSBO VIC](https://www.forsalebyowner.com.au/realestate/sales/vic/)
   - [FSBO NSW](https://www.forsalebyowner.com.au/realestate/sales/nsw/)
   - [FSBO SA](https://www.forsalebyowner.com.au/realestate/sales/sa/)
3. THIRD: Log extracted contacts to `~/agents/shared-data/scraped-contacts.json` then run `qualify`

**Apify MCP (INSTALLED — needs API token):**
Apify MCP is configured with 3 AU property scrapers. To activate:
1. Sign up at https://apify.com (free $5/month credits)
2. Get API token from Settings → Integrations
3. Replace `YOUR_APIFY_TOKEN_HERE` in `~/.claude.json` under `mcpServers.apify.env.APIFY_TOKEN`
4. Restart Claude Code

Once activated, these Apify actors are available:
- `scrapemind/domaincomau-scraper` — domain.com.au listings with agent contacts ($1/1K)
- `abotapi/realestate-au-scraper` — realestate.com.au property data
- `scrapemind/ausscraper` — general AU real estate scraper

Usage after activation:
```
/lead-generator scrape-listings melbourne --apify    # Uses Apify instead of Playwright
/lead-generator scrape-sellers sydney --apify        # Bypasses bot protection
```
```
Available states for FSBO: `vic`, `nsw`, `sa`
- FSBO sites may return phone codes instead of direct numbers — log these with the code and the main number (1300 114 970)
- After scraping, score and add to pipeline as `type: "seller"`

### For `prospect`:
1. Use the Vibe Prospecting MCP tools (`enrich-business`, `match-business`, `enrich-prospects`, `autocomplete`) to find property-related businesses in the target city
2. Use WebSearch to find "for rent by owner", "self-managed rental", "private landlord rental" listings in the target city
3. Use WebFetch to extract contact details from listing pages (name, phone, email, property address)
4. Score each prospect using the scoring criteria below
5. Save all leads to `~/agents/shared-data/leads-pipeline.json`
6. Post summary to Slack #sales channel via Slack MCP (`slack_send_message`)
7. Create follow-up tasks in Todoist for hot leads

### For `find-sellers`:
1. Use WebSearch to find motivated sellers in the target city:
   - Search "expired listing [city] Australia" — properties that failed to sell with previous agent
   - Search "for sale by owner [city]" OR "private sale [city]" — FSBO sellers with no agent
   - Search "deceased estate [city]" OR "mortgagee sale [city]" — distressed/motivated sellers
   - Search "withdrawn listing [city]" — sellers who pulled listings (may relist with right agent)
   - Search domain.com.au and realestate.com.au for listings with 90+ days on market (stale = motivated)
2. Use WebFetch on listing pages to extract: owner name, phone, email, property address, listing price, days on market, agent (if any)
3. Use Vibe Prospecting to enrich seller contact data
4. Score sellers using SELLER scoring criteria (see below)
5. Save to pipeline with `type: "seller"`
6. Slack alert for hot seller leads

### For `find-buyers`:
1. Use WebSearch to find active buyers in the target city:
   - Search "[city] property buyers group" OR "[city] first home buyer" on Facebook/Reddit — community groups
   - Search "looking to buy [city]" OR "wanting to buy property [city]" on social media
   - Search "pre-approved home loan [city]" — mortgage-ready buyers
   - Search "first home buyer grant [state] 2026" — first-home buyers researching
   - Search "[city] open home this weekend" — active inspection attendees
2. Use Vibe Prospecting to find buyer agent contacts and mortgage broker referral partners
3. Score buyers using BUYER scoring criteria (see below)
4. Save to pipeline with `type: "buyer"`
5. For pre-qualified buyers, match against current BPG listings if any

### For `scrape-expired`:
1. Use WebSearch + WebFetch to find expired/withdrawn listings on domain.com.au and realestate.com.au
2. Look for properties listed 90+ days ago with no "sold" status — these are likely expired or about to expire
3. Search "[suburb] sold results" to cross-reference what HAS sold vs what hasn't
4. Extract agent details from expired listings — the seller may want a new agent
5. Draft a personalized outreach message: "I noticed your property at [address] — I have a different approach that gets results"
6. Save with `type: "seller"`, `tags: ["expired-listing"]`

### For `scrape-forsale`:
1. Use WebSearch + WebFetch to scrape current for-sale listings in the target city and price range
2. Extract: address, price, agent, agency, days on market, property type, bedrooms
3. Identify opportunities:
   - Properties with no offers after 30+ days
   - Overpriced listings compared to recent sales in the suburb
   - Listings with multiple price reductions
4. Save as market intelligence to `~/agents/shared-data/market-data/`

### For `enrich`:
1. Use Vibe Prospecting MCP (`enrich-business`, `enrich-prospects`) to get company/person data
2. Use WebSearch to find additional context (Google reviews, social profiles, property portfolio size)
3. Output enriched lead profile with all available contact methods

### For `score` and `qualify`:
1. Read leads from `~/agents/shared-data/leads-pipeline.json`
2. Score using TYPE-SPECIFIC criteria:

**LANDLORD scoring (property management leads):**
   - Property owner signals (+30): owns rental property, self-managing, multiple properties
   - Intent signals (+25): visited BPG website, submitted form, asked about fees
   - Urgency signals (+20): "looking for manager", "need help", "bad tenant"
   - Budget signals (+15): property value, portfolio size, suburb affluence
   - Engagement signals (+10): email opens, return visits, referral from partner

**SELLER scoring (listing leads):**
   - Motivation signals (+30): expired listing, FSBO, price reductions, 90+ days on market
   - Life event signals (+25): divorce, deceased estate, relocation, downsizing, upsizing
   - Property signals (+20): property value > $500K, desirable suburb, well-maintained
   - Timing signals (+15): "need to sell quickly", spring/autumn market, pre-auction
   - Engagement signals (+10): responded to outreach, attended open home, requested appraisal

**BUYER scoring (purchase leads):**
   - Finance signals (+30): pre-approved, stated budget, deposit ready, first-home grant eligible
   - Intent signals (+25): actively inspecting, shortlisted suburbs, engaged with listings
   - Timeline signals (+20): "looking to buy this quarter", lease ending, relocating
   - Profile signals (+15): first-home buyer (grant eligible), investor (multiple purchases), upgrader
   - Engagement signals (+10): signed up for alerts, attended open homes, asked about properties

3. Classify: **Hot** (80+) → immediate call, **Warm** (50-79) → email drip, **Cold** (<50) → newsletter
4. Save scored leads back to pipeline JSON

### For `drip-landlord`, `drip-seller`, `drip-buyer`, `drip-investor`, `drip-first-home`:
1. Generate the email sequence using sales psychology and neuromarketing principles:

**Landlord Drip (5 emails over 21 days):**
- **Day 0** — "Thanks for your enquiry — here's what makes BPG different" (value proposition, social proof: 500+ properties, 4.9★)
- **Day 3** — "5 costly mistakes self-managing landlords make in [city]" (pain points, fear of loss)
- **Day 7** — "[City] rental market report — what your property could earn" (data, authority, FOMO)
- **Day 14** — "Case study: How we increased [landlord]'s yield by 15%" (proof, testimonial)
- **Day 21** — "Your free property appraisal is waiting — book in 60 seconds" (CTA, urgency, scarcity)

**Seller Drip (5 emails over 21 days):**
- **Day 0** — "Your property valuation request — here's what we found" (instant value)
- **Day 5** — "Is now the right time to sell in [city]? Market data inside" (authority, data)
- **Day 10** — "3 comparable sales near your property — what they achieved" (social proof)
- **Day 15** — "Meet your dedicated agent — their track record in [suburb]" (trust, credentials)
- **Day 21** — "Ready to list? Here's our no-obligation next step" (soft CTA, low commitment)

**Investor Drip (5 emails over 21 days):**
- **Day 0** — "Your investment property enquiry — the numbers that matter" (ROI focus)
- **Day 5** — "Top 5 suburbs for rental yield in [city] right now" (data, opportunity)
- **Day 10** — "How our guaranteed rent scheme protects your investment" (risk reduction)
- **Day 15** — "Portfolio growth: managing multiple properties under one roof" (scalability)
- **Day 21** — "Let's build your property strategy — free consultation" (partnership CTA)

**Buyer Drip (5 emails over 21 days):**
- **Day 0** — "Welcome — your [city] property search starts here" (value, what BPG offers buyers)
- **Day 3** — "5 properties matching your criteria just listed in [city]" (curated listings, relevance)
- **Day 7** — "[City] buyer's market report — where the opportunities are right now" (data, insider knowledge)
- **Day 14** — "How our buyers saved $40K on average with off-market deals" (exclusivity, savings proof)
- **Day 21** — "Ready to inspect? Book a private viewing this weekend" (action CTA, urgency)

**First-Home Buyer Drip (5 emails over 21 days):**
- **Day 0** — "Congrats on starting your property journey — here's your step-by-step guide" (encouragement, roadmap)
- **Day 3** — "You could save up to $75K — every first-home grant and scheme in [state] for 2026" (money saved, grants)
- **Day 7** — "How to get pre-approved in 48 hours — and why it gives you an edge" (actionable, competitive advantage)
- **Day 14** — "First-home buyer success story: How [name] bought in [suburb] with just 5% deposit" (social proof, achievability)
- **Day 21** — "3 properties in your budget range just listed — let's go see them" (specific listings, action CTA)

2. Use Gmail MCP (`create_draft`) to create draft emails for review, or `send` if user approves auto-send
3. Use Todoist MCP (`add-tasks`) to create follow-up reminders for each drip step
4. Log all outreach to `~/agents/shared-data/outreach-log.json`

### For `follow-up`:
1. Read `~/agents/shared-data/outreach-log.json`
2. Find leads where `next_action.date` is today or overdue
3. Draft personalized follow-up messages based on lead history and last interaction
4. Present drafts to user for approval before sending
5. Use Gmail MCP to send approved messages
6. Update outreach log with new interaction

### For `pipeline`:
1. Read `~/agents/shared-data/leads-pipeline.json`
2. Display pipeline summary grouped by stage and score:
   ```
   === BPG Lead Pipeline ===

   🔴 HOT (80+):   12 leads — 3 need immediate follow-up
   🟡 WARM (50-79): 34 leads — 8 due for nurture email
   🔵 COLD (<50):   67 leads — next newsletter in 5 days

   By Type:
   - Landlords:  45  |  Sellers: 28  |  Buyers: 22
   - Investors:  12  |  Tenants:  6  |  Partners: 0

   Landlord Pipeline:
   - New → Contacted → Qualified → Appraisal Booked → Management Signed

   Seller Pipeline:
   - New → Contacted → Appraisal Done → Listed → Under Offer → Sold

   Buyer Pipeline:
   - New → Contacted → Pre-Approved → Inspecting → Offer Made → Exchanged → Settled
   - Converted:        29

   This Week: 4 appraisals booked, 2 listings signed
   Conversion Rate: 8.2% (leads → signed)
   ```

### For `property-alert`:
1. Read the buyer's criteria (suburb, bedrooms, budget, property type) from the lead in pipeline
2. Use WebSearch to find new listings on domain.com.au and realestate.com.au matching criteria
3. Use WebFetch to extract listing details (price, photos, address, open home times)
4. Draft a personalized email: "Hi [name], 3 new properties just listed in [suburb] within your budget"
5. Include listing links, key details, and open home dates
6. Use Gmail MCP to send or draft
7. Log in outreach-log.json

### For `book-inspection`:
1. Draft email to buyer: "Hi [name], I've arranged a private inspection at [property address] — here are the available times"
2. Use Google Calendar MCP (`suggest_time`) to find mutual availability
3. Use Google Calendar MCP (`create_event`) to create the inspection event
4. Send confirmation via Gmail MCP
5. Create Todoist follow-up task for post-inspection feedback call

### For `campaign`:
1. Determine campaign type and target audience. Available campaign types:
   - **landlord-acquisition** — Target self-managing landlords who need property management
   - **seller-outreach** — Target property owners ready to sell (expired listings, FSBO, life events)
   - **buyer-attraction** — Target active property buyers (pre-approved, first-home, upgraders)
   - **first-home-buyer** — Specifically target first-home buyers (grants, schemes, step-by-step guidance)
   - **investor-acquisition** — Target property investors wanting portfolio growth
   - **partner-recruitment** — Recruit referral partners (agents, brokers, accountants)
   - **tenant-attraction** — Fill vacancies with quality tenants
2. Generate complete campaign plan including:
   - **Ad copy** for Meta/Google Ads (3 variants each)
   - **Landing page copy** optimized for conversion
   - **Email sequence** (5-email drip for the audience)
   - **Social media posts** (5 posts for Facebook/Instagram/LinkedIn)
   - **Budget recommendation** and expected ROI
   - **Timeline** (4-week rollout plan)
3. Save campaign plan to `~/agents/shared-data/campaigns/`

### For `report`:
1. Read pipeline data + outreach log
2. Calculate metrics: leads generated, qualified, converted, cost per lead, channel performance
3. Generate report with charts and recommendations
4. Save to `~/agents/shared-data/lead-reports/`
5. Post summary to Slack

### For all other arguments (legacy Python agent):
```bash
python3 /Users/archerterminez/agent activate lead-generator $ARGUMENTS
```

## Data Files

| File | Purpose |
|------|---------|
| `~/agents/shared-data/leads-pipeline.json` | Master lead pipeline with scores and stages |
| `~/agents/shared-data/outreach-log.json` | Email/SMS outreach history with dates |
| `~/agents/shared-data/lead-reports/` | Generated performance reports |
| `~/agents/shared-data/campaigns/` | Campaign plans and assets |

## MCP Tools Used

| Tool | Purpose |
|------|---------|
| **Vibe Prospecting** | `enrich-business`, `match-business`, `enrich-prospects`, `autocomplete` — prospect discovery and enrichment |
| **Gmail** | `create_draft`, `search_threads`, `get_thread` — email outreach and drip campaigns |
| **Google Calendar** | `create_event`, `suggest_time` — appraisal booking |
| **Slack** | `slack_send_message`, `slack_search_public` — team notifications, lead alerts |
| **Todoist** | `add-tasks`, `find-tasks`, `update-tasks` — follow-up task management |
| **Supabase** | `postgrestRequest` — lead storage if database is configured |
| **Linear** | `save_issue` — create tasks for sales team follow-up |

## Lead Schema

```json
{
  "id": "lead-uuid",
  "name": "John Smith",
  "email": "john@example.com",
  "phone": "0412345678",
  "type": "landlord|seller|buyer|tenant|investor|partner",
  "score": 85,
  "status": "hot|warm|cold",
  "stage": "new|contacted|qualified|appraisal-booked|listing-signed|converted|lost",
  "source": "website-form|referral|scrape|ad|chat|direct-outreach",
  "city": "Sydney",
  "properties": [
    {
      "address": "42 Smith St, Surry Hills NSW 2010",
      "type": "apartment",
      "bedrooms": 2,
      "value_estimate": 750000,
      "rental_estimate_weekly": 650
    }
  ],
  "interactions": [
    {
      "date": "2026-05-20",
      "type": "email",
      "subject": "Welcome to BPG",
      "status": "sent"
    }
  ],
  "next_action": {
    "date": "2026-05-23",
    "action": "Send market report email",
    "drip_step": 2
  },
  "tags": ["self-managing", "multiple-properties", "high-value"],
  "created_at": "2026-05-20T10:00:00Z",
  "updated_at": "2026-05-20T10:00:00Z"
}
```

## Scoring Criteria (Property Management)

| Signal | Points | Example |
|--------|--------|---------|
| Owns rental property | +15 | Listed on realestate.com.au as private landlord |
| Self-managing (no agent) | +15 | "For rent by owner" listing |
| Multiple properties | +10 | Portfolio of 3+ |
| High-value suburb | +10 | Median house price > $1M |
| Submitted BPG form | +20 | Website form submission |
| Partner referral | +15 | Referred by existing partner |
| Asked about fees/pricing | +10 | Visited pricing page or asked in chat |
| Urgency language | +10 | "Need help ASAP", "bad tenant", "vacant property" |
| Return website visitor | +5 | 3+ sessions in GA4 |
| Opened previous email | +5 | Email engagement tracked |
| Phone number provided | +5 | Higher contact quality |
