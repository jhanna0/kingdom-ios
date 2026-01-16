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


Every kingdom on the map is ruled by a real person. Every coup and invasion involves real players picking sides and fighting.

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

**Reputation is earned per kingdom**. Switching kingdoms resets it to 0. This prevents randoms from switching to your kingdom and couping.
"""

    ),
        TutorialSection(
        id="getting_started",
        title="Getting Started",
        icon="hammer.fill",
        order=2,
        content="""
Actions require **food** to perform.

**To start playing:**
- **Hunt** to get meat (and maybe some rare loot)
- **Farm** to turn that meat into gold
- **Patrol** to turn that meat into reputation and protect your city
- **Train skills** using your gold
"""
    ),
    TutorialSection(
        id="becoming_ruler",
        title="Becoming a Ruler",
        icon="person.crop.circle.badge.checkmark",
        order=3,
        content="""
**"I'm visiting a town with no ruler. Can I claim it?"**

No. You can only claim your **Home Kingdom**. If you want to rule somewhere else:
- Switch your home there (but then you lose the ability to play in your hometown)
- Coup your current ruler, then invade that town
- Or convince your ruler to **invade** it and appoint you as leader

**"I already rule. Can I claim another kingdom?"**

No. One claim, ever. Want more territory? **Conquer it.**

**"Can I invade an unruled town?"**

No. Invasions need a defender. Unruled towns can only be claimed by locals.
"""
    ),
    TutorialSection(
        id="location",
        title="Location Matters",
        icon="location.fill",
        order=4,
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
        order=5,
        content="""
Every coin in circulation was earned or traded.

Building, working, contracts, and trading flow coins.

Kingdoms take a cut of income by taxes and travel fees.

**Rulers cannot donate to kingdom treasury. Gold must be earned by citizens. Rulers pay no tax.**

Build a **Vault** or enemies can heist your treasury.
"""
    ),
    TutorialSection(
        id="skills",
        title="Skills & Training",
        icon="figure.strengthtraining.traditional",
        order=6,
        content="""
Train skills to get stronger. Check your profile for available skills.

Skills unlock new content and give your character powerful perks.

**How:** Buy training contracts → complete training actions.

**Cost:** Based on your TOTAL skill points across all skills. Every skill you train makes the next one more expensive. Therefore, it's very difficult to max an account. Pick the build path you think is best.

**Tip:** Education buildings reduce actions needed.
"""
    ),
    TutorialSection(
        id="buildings",
        title="Buildings",
        icon="building.2.fill",
        order=7,
        content="""
Kingdoms construct buildings for permanent bonuses. These are citizen wide.
Citizen perform the actions to build. Number of actions required for a building scales to the population of a kingdom.

The most powerful player is one with the highest character skills, in the most developed kingdom.
Contributing as often as possible to kingdom buildings is recommended for optimizing your kingdom.

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
        order=8,
        content="""
Don't like your ruler? Overthrow them.

**How it works**
1. **Pledge Phase (12h)** — citizens pick sides
2. **Battle Phase** — fight over 3 territories
3. **First to capture 2 wins**

**To start:** T3 Leadership, 500 reputation, physically present.
**To join:** 100 reputation, then show up and fight.

The best coups are coordinated. Communicate often with your team.
"""
    ),
    TutorialSection(
        id="invasions",
        title="Invasions",
        icon="shield.lefthalf.filled",
        order=9,
        content="""
Rulers can declare war on other kingdoms. Win and absorb them into your empire.

**Once declared:**
1. **Preparation Phase (12h)**- Both sides coordinate
2. **Battle Phase**- fight over 5 territories
3. **First to capture 3 wins**

**To declare:** Be a ruler, physically visit the target first.
**To join:** Must have visited that kingdom once, then fight from anywhere.

**Walls matter.** They boost defender defense.

A kingdom can only be attacked once every 30 days.
"""
    ),
    TutorialSection(
        id="sabotage",
        title="Intelligence & Sabotage",
        icon="eye.fill",
        order=10,
        content="""
Can't invade yet? Disrupt them anyway.

Intelligence operations let you spy on and sabotage enemy kingdoms. Must be physically present in their territory.

**What you can do:**
- **Steal Military Intelligence** — reveal their total Attack, Defense, Leadership, Population, and Wall strength
- **Citizen Intel** — see who's doing what in their kingdom
- **Project Sabotage** — add extra actions to their current building project, delaying completion
- **Vault Heists** — steal gold directly from their treasury

**Requirements:** Train Intelligence skill to unlock operations. Higher tiers unlock more powerful actions.

**Risk:** Failed operations can alert the target ruler and expose your identity.

Coordinate with your allies. Good intel wins wars before they start.
"""
    ),
    TutorialSection(
        id="battles",
        title="Battle System",
        icon="burst.fill",
        order=11,
        content="""
**The "300" problem**

If we calculated att vs def linearly, 10,000 vs 1,000 would be a 10:1 power blowout.

To solve this, we implement an army-size effectiveness reduction.

10,000 vs 1,000 isn't 10:1 — it's closer to **3:1**. Smaller armies with a plan can win. Especially when coordinating strategies across the different territories.

Armies with higher leadership skills suffer less of this scaling penalty.

**Stats**
- **Attack** — chance to land hits
- **Defense** — chance to block, slows territory loss
- **Leadership** — army effectiveness at scale

**Mechanics:** Tug of war. Each round: MISS, HIT, or INJURE. Your Attack vs their Defense.

Try the **Battle Simulator** to see it in action.
"""
    ),
    TutorialSection(
        id="notifications",
        title="Notifications",
        icon="bell.fill",
        order=12,
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
