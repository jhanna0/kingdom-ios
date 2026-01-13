"""
Tutorial / Help Book Router

Serves tutorial content for the in-app help system.
Content is structured as sections that can be updated without app releases.
"""

from fastapi import APIRouter
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/tutorial", tags=["tutorial"])


class TutorialSection(BaseModel):
    """A section of the tutorial/help book"""
    id: str
    title: str
    icon: str  # SF Symbol name
    content: str  # Markdown-style content
    order: int


class TutorialResponse(BaseModel):
    """Full tutorial content response"""
    version: str
    sections: List[TutorialSection]


# Tutorial content - easily updateable on the backend
# Beginner-first ordering: orient new players around their Home Kingdom and core loop,
# then introduce war/politics once the basics are clear.
TUTORIAL_SECTIONS = [
    TutorialSection(
        id="welcome",
        title="Welcome",
        icon="crown.fill",
        order=0,
        content="""
**Kingdom: Territory**- real players fighting for control of real cities.


Every kingdom on the map is ruled by a real person. Every gold coin was earned by someone. Every coup and invasion involves real players picking sides and fighting.

There are no NPCs. Just you and everyone else.
"""
    ),
    TutorialSection(
        id="home_kingdom",
        title="Your Home Kingdom",
        icon="flag.fill",
        order=1,
        content="""
You get **one** Home Kingdom. Pick the place you spend time the most time. That's where you will work, build reputation, and participate in local politics & events.

**What you do there**
- **Build** upgrades to your city & earn gold
- **Earn reputation** by contributing to the kingdom
- **Defend** your territory when enemies attack
- **Coup** the ruler if you don't like how things are run
"""
    ),
    TutorialSection(
        id="becoming_ruler",
        title="Becoming a Ruler",
        icon="person.crop.circle.badge.checkmark",
        order=2,
        content="""
**"I'm visiting a town with no ruler. Can I claim it?"**

No. You can only claim your **Home Kingdom**. If you want to rule somewhere else:
- Switch your home there (but then you lose your current home)
- Or convince a ruler to **invade** it and appoint you as leader

**"I already rule. Can I claim another kingdom?"**

No. One claim, ever. Want more territory? **Conquer it.**

**"Can I invade an unruled town?"**

No. Invasions need a defender. Unruled towns can only be claimed by locals.

**"Can I donate gold to the treasury?"**

No. The treasury only grows from **citizen actions** — taxes, travel fees, market income. You can't just dump gold in. Rulers depend on active citizens.

**The path to power:** Claim your home → Coup your ruler → Invade for empire.
"""
    ),
    TutorialSection(
        id="location",
        title="Location Matters",
        icon="location.fill",
        order=3,
        content="""
Where you physically are determines what you can do.

**In your territory:** Work, build, defend.

**In enemy territory:** Invade, sabotage, fight.

Your actions matter where you actually are.
"""
    ),
    TutorialSection(
        id="gold",
        title="Gold & Treasury",
        icon="g.circle.fill",
        order=4,
        content="""
Every coin was earned by a real person. No NPCs.

**Citizens earn by:** Working, contracts, trading.

**Rulers earn by:** Taxing labor (0-100%), charging travel fees, market income. All of this flows into the **kingdom treasury**.

**The catch:** Rulers can't work in their own kingdom. Tax too hard and citizens will coup you.

**Protecting gold:** Build a **Vault** or enemies can heist your treasury.
"""
    ),
    TutorialSection(
        id="skills",
        title="Training",
        icon="figure.strengthtraining.traditional",
        order=5,
        content="""
Train skills to get stronger. Check your profile for available skills.

**How:** Buy training contracts → complete training actions.

**Cost:** Based on your TOTAL skill points across all skills. Every skill you train makes the next one more expensive.

**Tip:** Education buildings reduce actions needed.
"""
    ),
    TutorialSection(
        id="buildings",
        title="Buildings",
        icon="building.2.fill",
        order=6,
        content="""
Kingdoms construct buildings for permanent bonuses.

**Defense** — Walls (invasion protection), Vaults (treasury protection)
**Economy** — Mines, Markets, Farms, Lumbermills
**Civic** — Town Hall (group activities), Education (faster training)

**Construction** takes collective effort. Citizens work contracts to build. 5 tiers per building — higher = better.
"""
    ),
    TutorialSection(
        id="coups",
        title="Coups",
        icon="flame.fill",
        order=7,
        content="""
Don't like your ruler? Overthrow them.

**How it works**
1. **Pledge Phase (12h)** — citizens pick sides
2. **Battle Phase** — fight over 3 territories
3. **First to capture 2 wins**

**To start:** T3 Leadership, 500 reputation, physically present.
**To join:** 100 reputation, then show up and fight.

The best coups are coordinated. Build alliances. Strike when the ruler is weak.
"""
    ),
    TutorialSection(
        id="invasions",
        title="Invasions",
        icon="shield.lefthalf.filled",
        order=8,
        content="""
Rulers can declare war on other kingdoms. Win and absorb them into your empire.

**How it works**
1. **Declaration Phase (12h)** — defenders rally
2. **Battle Phase** — fight over 5 territories
3. **First to capture 3 wins**

**To declare:** Be a ruler, physically visit the target first.
**To join:** Must have visited that kingdom once, then fight from anywhere.

**Walls matter.** They boost defender defense.

**Cooldowns:** 30 days between invasions. 7 days after a coup.
"""
    ),
    TutorialSection(
        id="battles",
        title="Battle System",
        icon="burst.fill",
        order=9,
        content="""
**The "300" problem**

10,000 vs 1,000 isn't 10:1 — it's closer to **3:1**. Smaller armies with a plan can win.

**Stats**
- **Attack** — chance to land hits
- **Defense** — chance to block, slows territory loss
- **Leadership** — army effectiveness at scale

**Mechanics:** Tug of war. Each round: MISS, HIT, or INJURE. Your Attack vs their Defense.

**Try the Battle Simulator** to see it in action.
"""
    ),
    TutorialSection(
        id="notifications",
        title="Notifications",
        icon="bell.fill",
        order=10,
        content="""
**Settings → Action Notifications → Allow**

Get alerts for cooldowns, coup phases, and battles.
"""
    ),
]


@router.get("", response_model=TutorialResponse)
async def get_tutorial():
    """
    Get all tutorial sections for the help book.
    
    Returns structured content that can be displayed in-app.
    Sections are ordered and include icons for visual hierarchy.
    """
    return TutorialResponse(
        version="1.1.0",
        sections=sorted(TUTORIAL_SECTIONS, key=lambda s: s.order)
    )


@router.get("/section/{section_id}", response_model=TutorialSection)
async def get_tutorial_section(section_id: str):
    """
    Get a specific tutorial section by ID.
    
    Useful for deep-linking to specific help topics.
    """
    for section in TUTORIAL_SECTIONS:
        if section.id == section_id:
            return section
    
    from fastapi import HTTPException
    raise HTTPException(status_code=404, detail=f"Section '{section_id}' not found")
