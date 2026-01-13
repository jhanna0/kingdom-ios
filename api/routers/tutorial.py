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
**Kingdom: Territory** - real players fighting for control of real cities.

Overthrow tyrants. Build empires. Betray your allies. Or be the loyal citizen who tips the balance in a war.

Every kingdom on the map is ruled by a real person. Every gold coin was earned by someone. Every coup and invasion involves real players picking sides.

There are no NPCs. Just you and everyone else.
"""
    ),
    TutorialSection(
        id="claiming",
        title="Your Home Kingdom",
        icon="flag.fill",
        order=1,
        content="""
You get **one** Home Kingdom. Pick somewhere you'll actually spend time- that's where you'll have the most day-to-day actions.

**What your Home Kingdom is for**
- Earn gold and **reputation** by working there
- Help build structures and defend your territory
- Get to know the politics (and decide if you like your ruler)

**Ruling your Home**
- If it's unclaimed: claim it and become ruler
- If it's ruled: build reputation by working, then coup when you're ready

You can only claim one kingdom. Want more? Conquer them through invasion.
"""
    ),
    TutorialSection(
        id="location",
        title="Location Matters",
        icon="location.fill",
        order=2,
        content="""
This is a location-based game. Where you physically are matters.

**Helping your kingdom**
- Working, building, defending: do it while you're **inside your kingdom's territory**

**Attacking enemies**
- Invasions, sabotage, war actions: do it while you're **in THEIR territory**

Kingdom is about real places. Your actions matter where you actually are.
"""
    ),
    TutorialSection(
        id="gold",
        title="Gold & Economy",
        icon="g.circle.fill",
        order=3,
        content="""
**No NPCs. Real players only.**

Every coin was earned by a real person working. If a kingdom is poor, it needs more active citizens.

**How citizens earn**
- Work (labor, farming, crafting)
- Complete contracts
- Trade on the market

**How rulers earn**
- Set a tax rate (0–100%) on citizen labor
- Charge travel fees when players enter your territory
- Spend from the kingdom treasury

**The catch**
Rulers can't work in their own kingdom. You depend on citizens — tax too hard and they'll coup you.
"""
    ),
    TutorialSection(
        id="skills",
        title="Training",
        icon="figure.strengthtraining.traditional",
        order=4,
        content="""
Train skills to become more powerful. Check your player profile to see all available skills and their effects.

**How to Train**
- Buy training contracts (costs gold)
- Complete training actions
- Education buildings reduce actions needed

**Cost Scaling**

All skills cost the same to train. The cost is based on your TOTAL skill points across all skills - so every skill you train makes the next one more expensive.
"""
    ),
    TutorialSection(
        id="buildings",
        title="Buildings",
        icon="building.2.fill",
        order=5,
        content="""
Kingdoms can construct buildings for permanent bonuses. Check your kingdom to see available buildings and their effects.

**Categories**

- **Defense** - Walls protect against invasions, Vaults protect your treasury
- **Economy** - Mines, Markets, Farms, Lumbermills generate resources and income
- **Civic** - Town Hall unlocks group activities, Education speeds up training

**Construction**

Building takes collective effort. The bigger the kingdom's population, the more actions required. Citizens work on contracts to help build.

Each building has 5 tiers. Higher tiers = better bonuses.
"""
    ),
    TutorialSection(
        id="treasury",
        title="The Treasury",
        icon="building.columns.fill",
        order=6,
        content="""
Every kingdom has a treasury. This is the ruler's war chest.

**How It Fills**
- Taxes from citizen labor
- Travel fees from visitors
- Market income

**What It's For**
- Building walls, vaults, and other structures
- Funding kingdom operations
- Flexing on other rulers

**Protecting It**

Build a **Vault** to protect your treasury from heists. Without one, enemies can steal from you.
"""
    ),
    TutorialSection(
        id="coups",
        title="Coups",
        icon="flame.fill",
        order=7,
        content="""
Don't like your ruler? Overthrow them.

A coup is an internal rebellion. Citizens pick sides and battle for control.

**How it works**
- **Pledge Phase (12h)** - join the rebellion or defend the crown
- **Battle Phase** - fight over 3 territories
- **First to capture 2 wins**

**To start a coup**
- T3 Leadership skill
- 500 reputation in the kingdom (earned by working there)
- Be physically present

**To join**
- 100 reputation to pick a side
- Show up and fight

The best coups are coordinated. Build alliances. Strike when the ruler is weak.
"""
    ),
    TutorialSection(
        id="invasions",
        title="Invasions",
        icon="shield.lefthalf.filled",
        order=8,
        content="""
Rulers can declare war on other kingdoms.

Win an invasion and that kingdom joins your empire. Lose and your kingdom is punished.

**How it works**
- **Declaration Phase (12h)** - the target kingdom rallies defenders
- **Battle Phase** - fight over 5 territories
- **First to capture 3 wins**
- **Victory** - attacker absorbs the kingdom into their empire

**To declare**
- You must be a ruler
- Physically visit the target kingdom first

**To join**
- Must have visited that kingdom at least once
- Then you can fight from anywhere

**Walls matter.** They boost defender defense. Smart rulers invest in walls.

**Cooldowns:** 30 days before a kingdom can be invaded again. 7 days after a coup.
"""
    ),
    TutorialSection(
        id="battles",
        title="Battle System",
        icon="burst.fill",
        order=9,
        content="""
**The "300" problem**

We wanted large population differences to be fair, so battles use an **army coordination** calculation.

10,000 vs 1,000 is not a 10:1 power difference. **It's closer to ~3:1.**
That gives a smaller army with a plan a chance against huge invaders.

**How stats affect battle**
- **Attack** - increases your chance to land a hit
- **Defense** - increases your chance to block hits & makes territory loss slower
- **Leadership** - makes your army more effective at scale

**How battles work**
- Tug of war: push the bar to your side to win
- Each round you roll: MISS, HIT, or INJURE
- Your Attack vs their Defense determines hit or miss

**Try the Battle Simulator below** to see this in action.
"""
    ),
    TutorialSection(
        id="notifications",
        title="Notifications",
        icon="bell.fill",
        order=10,
        content="""
Turn on notifications so you don't miss anything.

**Settings → Action Notifications → Allow**

You'll get alerts when:
- Your cooldowns finish
- Coup phases change
- Battles need attention

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
        version="1.0.2",
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
