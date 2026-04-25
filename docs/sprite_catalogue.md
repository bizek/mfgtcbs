# Sprite Catalogue

Asset source: Minifantasy by Krishna Palacio (itch.io). 74 packs + Patreon exclusives archive, 8x8 pixel art, all 4-directional.

---

## A-List: Hero & Villain Sprites (Full Animation Sets + Specials)

These are our primary casting pool for player classes. Each has a deep animation set with unique special abilities that constrain and inspire class design.

### True Heroes I

**Barbarian**
- Visual: Horned helmet, massive sword. Raw physical power, storm-deity blessed.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Battle Cry, Block (giant sword), Thunder Blade Attack, Pick & Throw

**Druid**
- Visual: Forest hermit, nature magic. Shapeshifter.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Root Summoning, Shapeshift (3 forms)
  - Forest Beast: Idle, Walk, Attack, Dmg
  - Forest Hound: Idle, Walk, Jump, Attack, Dmg
  - Forest Owl: Fly/Idle, Attack, Dmg

**Rogue**
- Visual: Red attire, cunning and fast.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Sprint, Dodge, Shuriken Attack, Throw Bomb

### True Heroes II

**Bard**
- Visual: Musical performer, enchantment-based.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Dissonant Chord (projectile, 8-dir), Apotheosis, Ballad Song, Enhancement Song, Vicious Mockery Song
- 4 song effect animations

**Cleric**
- Visual: Divine staff wielder, fragile but determined.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Divine Fire (projectile, 8-dir), Healing Words, Word of Pain, Spirit Guardian (summon)
  - Spirit Guardian: Idle, Walk, Attack, Dmg, Die, Summon, Unsummon

**Paladin**
- Visual: Blue armor, holy warrior.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Blades of Justice, Dome of Rightfulness, Holy Hammer (projectile, 8-dir), Shield Bash

### True Heroes III

**Fighter (Dwarf)**
- Visual: Axe and shield, dwarven.
- Base: Idle (x2 variants), Walk, Jump, Attack, Dmg, Die
- Specials: Uppercut, Swirl (spin attack), Tempest (double rotation), Cataclysm (jumping strike), Taunt (shield)

**Ranger (Elf)** — EXTRACTED → `assets/sprites/ranger/`
- Visual: Agile archer, bows and blades.
- Base: Idle (x2 variants), Walk, Jump, Bow Attack (8-dir), Dmg, Die
- Specials: Double Arrow (8-dir), Triple Arrow (8-dir), Throwing Knife (8-dir), Single-Blade Melee, Double-Blade Melee, Conceal (hide + emerge)
- Extracted: `ranger_frames.tres` (14 anims), `ranger_effects_frames.tres` (melee overlays), `ranger_projectiles_frames.tres` (arrow, double_arrow, knife, knife_ground)

**Wizard (Human)**
- Visual: Fire mage, robed spellcaster.
- Base: Idle (x2 variants), Walk, Jump, Fire Melee Attack, Dmg, Die
- Specials: Fireball (8-dir, AOE), Fire Torrent (mid-range), Teleport (8-dir), Summon Fire Familiar
  - Fire Familiar: Summon, Fly/Idle, Attack, Die

### True Heroes IV

**Blood Mage**
- Visual: Dark spellcaster, forbidden blood rituals. Power at personal cost.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Blood Shards, Blood Slam, Blood Spikes, Vampirize, Summon Blood Elemental
  - Blood Elemental: Idle, Move, Attack, Dmg, Die

**Ninja Assassin**
- Visual: Stealth master, shadow magic.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Smoke Bomb, Deadly Dash, Thousand Blades, Sharpen Blade, Enter the Shadows
- Shadow Mode: Idle, Walk, Ambush Attack, Dmg, Ambush Deadly Dash, Ambush Thousand Blades

**Tech-Augmented Gunslinger**
- Visual: Cybernetic sharpshooter, old-west meets sci-fi.
- Base: Idle, Walk, Jump, Single Shot, Dmg, Die
- Specials: Whip Attack, Fan the Hammer, Reload, Desert Storm

### True Villains I

**Dark Priest**
- Visual: Black ceremonial robes, corrupted sceptre, heavy shield.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Crush, Shielding (Block + Shield Breach), Retaliation, Dark Wings

**Demonologist** — EXTRACTED (red original) → `assets/sprites/demonologist/`
- Visual: Scholarly figure corrupted by forbidden knowledge. Red robes, fire/demon theme.
- Base: Idle, Walk, Jump, Attack, Dmg, Die (+ no_effect/only_effect variants for attack & die)
- Specials: Hellfire, Archdemon Call, Hell Breach (spell effect 64×64), Summon Ritual, Standalone Summon
  - Angry Demon: Idle, Walk, Attack, Dmg, Die
- Extracted: `witch_doctor_frames.tres` (14 anims), `witch_doctor_effects_frames.tres` (spell VFX), `angry_demon_frames.tres` (summon unit)

**Witch Doctor** — PALETTE SWAP of Demonologist → `assets/sprites/witch_doctor/`
- Visual: Same base sprite as Demonologist, recolored to deep violet/purple for shadow magic theme.
- Base: Idle, Walk, Jump, Attack, Dmg, Die (+ no_effect/only_effect variants for attack & die)
- Specials: Hellfire, Archdemon Call, Hell Breach, Summon Ritual, Standalone Summon
  - Angry Demon: Idle, Walk, Attack, Dmg, Die (unchanged — demon sprites not recolored)
- Palette swap recipe: see "Executed Palette Swaps" section below

**Supreme Necromancer**
- Visual: Skeletal master in luxurious gold-adorned robes, hollow eye sockets.
- Base: Idle, Walk, Jump, Attack, Dmg, Die
- Specials: Plane Shift (in/out), Soul Shape (idle/fly), Bone Missile, Bone Swirl, Rise Skeletal Champion
  - Skeletal Champion: Idle, Walk, Attack, Dmg, Die

---

## B-List: Military & Faction Units (Standard Animation Sets)

Full combat animation sets (Idle, Walk, Attack, Dmg, Die) but no unique specials. Good for enemies, NPCs, or classes where the base kit is sufficient.

### RTS Humans
- Archer, Knight, Spearman, Swordsman
- Worker (Attack_Axe, Attack_Hammer, Attack_Pickaxe variants)

### RTS Orcs
- Berserk, Hunter, Raider, Warrior, Worker

### Dark Orc Army (14 units)
- Orc_Blade, Orc_Raider (+ Bite), Orc_Scout (ranged)
- Feral_Arbalist (ranged), Feral_Berserker, Feral_Blade, Feral_Phalanx
- Warbreed_Arbalist (ranged), Warbreed_Berserker, Warbreed_Blade, Warbreed_Phalanx
- Cave_Troll, Pale_Champion, Warg (Bite)

### Dark Brotherhood (12 units)
- Acolyte, Zealot, Flagellant, Ritual_Guard
- Devoted_Blade, Devoted_Sentinel, Devoted_Stalker (ranged)
- Dark_Cultist, Dark_Hound, Dark_Abomination
- Dark_Channeler (Cast_Spell, Possession animations — can possess Acolyte/Hound/Zealot)

---

## C-List: NPCs & Profession Sprites (No Attack Animations)

Idle, Walk, Dmg, Die, Working. No combat. Perfect for base characters (Crafter archetype) or town NPCs.

### Myriad of NPCs (Premade)
- Alchemist, Blacksmith, Butcher, Carpenter, Cooker, Dyer, Furrier, Jeweller, Tailor

### Modular NPC System (same pack)
- Human, Elf, Orc base bodies
- Clothing layers: Blouses, Doublets, Shirts, Jackets, Togas (15 colors each), Trousers, Gloves, Shoes, ShoulderPads
- Hair: 8 styles, Hats: 8 types, Facial Hair: 5 types
- Animations: Idle, Walk, Dmg, Die only

---

## D-List: Creatures & Monsters

### Creatures Pack (Base Humanoids + Monsters)
**Humanoids** (Idle, Walk, Jump, Attack, ChargedAttack, Dmg, SpinDie):
- Base Human, Human Amazon, Human Townsfolk
- Base Orc, Wild Orc
- Base Dwarf, Dwarf Yellow Beard
- Base Elf, Base Goblin, Base Halfling

**Monsters** (varying animation sets):
- Bat, Warg, Wolf
- Centaur, Cyclop, Minotaur, Troll, Yeti
- Evil Snowman, Pumpkin Horror, Trasgo
- Skeleton, Zombie, Wildfire
- Green/Blue Slime, Green/Blue Mother Slime

### Monster Creatures (Boss-tier)
- Angel of Death, Brain Slayer, Centaur King, Demon Spider
- Gargoyle, **Giant** — EXTRACTED → `assets/sprites/giant/`, Giant Rat, Gnoll
- Predatory Mushroom, Rat People, Rat People Royalty
- Werewolf
- Chest Mimic (Aggressive + Shy variants)
- Deep One

### Undead Creatures (14 units)
- Ghost, Headless Skeleton, Jumping Skull
- Reanimated Skeleton: Archer, Mage, Warrior
- Reanimated Zombie: Archer, Mage, Warrior
- Skeletal Horse (+ Rider variant), Skeleton Minotaur
- Zombie Bear, Zombie Giant, Zombie Minotaur

### Forest Dwellers
- Alpha Creeper, Creeperlings, Fungifyed Corpse
- Necrofungus, Necrothallus
- Tree Spirits (5 types: Birch, Hickory, Oak, Pine, Willow) — have Heal and PlantSeed animations

### Wildlife (27 animals)
- Combat: Hyena, Lion, Lioness, Polar Bear, Rhino, Snake, Tiger
- Non-combat: Badger, Camel, Cat, Dog, Elephant, Frog, Giant Snail, Goat, Hedgehog, Hippo, Horse, Kangaroo, Moose, Orange Fox, Ostrich, Panda, Platypus, Polar Fox, Skunk, Squirrel, Tortoise

### Aquatic Adventures
- 6 base races with swim/dive/emerge animations
- Dolphin, Frogfolk, Kraken, Otter, Shark, Water Elemental

### Lost Jungle
- Raptor, Stegosaurus, Triceratops (all: Idle, Walk, Attack, Dmg, Die)

### Silent Swamp
- Crocodile, Giant Toad, Swamp Ogre, Tentacle

### Enchanted Companions (20 companions)
- Baby Beholder, Book, Bulldog, Cactus, Carrier, Cherub, Chest, Cloud
- Draco (fire-breathing), Egg, Hive & Bee, Lizard
- Orbs (Air, Fire, Ice, Rock), Rolling Stone
- Shadow, Skull, Sprite, Sword (floating/animated)

---

## E-List: Mounts
- War Horse, Unicorn, Magic Carpet, Bicycle, Canoe
- Rider integration layers for other animals

---

## Support Packs (No Characters, But Relevant)

### Weapons (layered on base 6 races)
- 14 weapon types across 5 attack categories: Ranged, Slash, Swing, Thrust, Two-Handed, Guard
- Base bodies: Human, Elf, Dwarf, Orc, Goblin, Halfling (attack animations only)

### Magic & Sorcery (layered on base 6 races)
- 5 magic types: Holy Aura, Magic Explosions, Magic Projectiles, Magic Shields, Power Charging

### Magic Weapons & Effects
- 11 elemental variants: Bleed, Fear, Fire, Ice, Nature, Petrification, Poison, Shock, Sickness, Sleep, Stun
- 7 attack effect types, 11 hit effects, 11 loopable status effects
- 7 magic weapon types + 4 legendaries

### Spell Effects I & II
- Standalone spell/magic visual effects

### Portrait Generator
- Modular face builder: 6 races, mix-and-match eyes/mouth/hair/ears/clothing
- Animated portraits (blinking/talking) — for UI character panels

---

## Patreon Exclusives (Owned — `All_Exclusives_20260409/`)

Subscribed April 2026. Massive archive of additional creatures, pack addons, seasonal environment packs, and icon sets.

### Patreon Creatures (~100+ units)

All use standard animation sets (Idle, Walk, Attack, Dmg, Die) unless noted. Source: `All_Exclusives_20260409/Creatures/`.

**Wildlife & Beasts:**
- Ape (2 color variants) — Idle, Walk, Attack, ChestHits, Dmg, Die
- Birds — Small/Mid/Big, 3 color variants each. Full flying set: Idle, Flapping, Gliding, Takeoff/Landing, Dmg, Die, FlyingDmg, FlyingDie
- Capybara — Idle, Walk, Dmg, Die, Sleep (start/loop/end). No attack
- Dire Bear — Idle, Walk, Attack, Dmg, Die, Sleep
- Giant Scorpion — Idle, Walk, Attack + effect, Dmg + effect, Die + effect
- Giant Snake — Idle, Walk, Jump, Attack, Dmg, Die + Choking animation
- Giant Spider — Idle, Walk, Attack, Dmg, Die + Web Shot (diagonal/orthogonal) + Web Projectiles
- Giant Tortoise — Idle, Walk, Dmg, Die + Shell In/Out/Spin
- Giant Turkey — standard combat set
- Huntsman Spider — standard combat set + effects
- Insect Swarm — Idle, Attack, Dmg, Die, Fly (diagonal/orthogonal). Flying enemy
- Mouse — Idle, Walk, Die. No attack, no Dmg
- Rune Bear — Idle, Walk, Attack + effect, Dmg, Die
- Shark — Idle (3-phase), Swim, Attack, Dmg, Die + Emerge/Submerge

**Elementals & Constructs:**
- Air Elemental — Idle, Walk, Attack (diagonal/orthogonal), Dmg, Die + Wind Explosion/Projectile
- Earth Elemental — Idle, Walk, Attack, Dmg, Die + Activation/Deactivation + Root Attack
- Fire Elemental — Idle, Walk, Dmg, Die + Fireball Attack (diagonal/orthogonal) + Fireball Explosion/Projectile + Light effects
- Water Elemental — Idle, Walk, Attack, Dmg, Die + Ice Shard/Impact projectiles
- Magma Golem — Idle, Walk, Attack + Magma Burst effect, Dmg, Die + Magma Puddles
- Rock Golem — Walk, Attack, Dmg, Die + Rock-to-Golem/Golem-to-Rock transformation
- Dwarven Stone Guardian — Idle, Walk, Attack + effect, Dmg, Die + Activation/Deactivation + Smoke
- Supreme Elemental — Idle, Walk, Attack + effect, Dmg, Die + Summon Lesser Elementals
- Orb Sentinel — Idle, Fly, Dmg, Die + Open/Close + Shot (diagonal/orthogonal) + Projectile/Impact

**Undead & Dark:**
- Ancient Vampire — Idle, Walk, Attack, Dmg, Die + Transformation
- Burning Skull — Idle, Floating, Dmg, Die + Direct/Telegraphed Explosion. Flying
- Ferryman of the Dead — Idle, Walk, Attack, Dmg, Die + Soul (Appear/Disappear/Floating) + Riding Boat
- Grim Reaper — standard combat set
- Headless Horseman — standard combat set + glow effect
- King Skeleton — Idle, Walk, Attack, Dmg, Die + Activation/Deactivation
- Lich — Idle, Fly, Dmg, Die + Ice Claws spell + Skeleton/Zombie Reanimation spellcast
- Necromancer — Idle, Walk, Dmg, Die + Spellcast + Skeleton/Zombie summon
- Spectre — standard combat set (outlined/non-outlined variants)
- Undead Dragon — Idle, Walk, Attack, Dmg + effect, Die + effect
- Undead Knight — Idle, Walk, Attack, Dmg, Die + Activation/Deactivation
- Wraith — Idle, Floating, Attack, Dmg, Die + Icy Touch + Through Floor

**Demons & Nightmare:**
- Balrog — Idle, Walk, Attack, Dmg, Die + Wings (separate layer)
- Demon Lord — Idle, Walk, Attack + effect (ground), Dmg, Die
- Diablo — Idle, Walk, Attack, Attack2 (diagonal/orthogonal), Dmg, Die + Fireball Explosion/Projectile
- Imp — Idle, Fly, Dmg, Die + Melee Attack (with/without effect) + Ranged (diagonal/orthogonal) + Projectile/Impact
- PileOfFlesh — Idle, Dmg, Die + Spawn Minion + Spawn Minions On Die. Has Flesh Minion sub-unit
- Shoggoth's Avatar — Idle, Walk, Dmg + effect, Die + Crawler form (Crawl/Dmg/Die) + Tentacle Attack
- The King In Yellow — Disguised form + True Form: Idle, Walk, Attack + tentacle, Dmg, Die + In/Out transition
- The Void — Idle, Walk, Attack (diagonal/orthogonal), Dmg, Die + Void Vortex (Start/Loop/End)

**Bosses & Large Creatures:**
- Beholder — Idle, Fly, Attack, 360Attack, Dmg, Die
- Chimera — 2 visual variants (Alternative/Creepy). Idle, Walk, Attack, Fire Attack, Dmg, Die
- Cockatrice — standard combat set + effects
- Dragon — Idle, Walk, Attack (Start/Continuous/End), Dmg, Die
- Dragon Hatchling — standard combat set + effects
- Griffin — Idle, Walk, Fly, Attack, Dmg, Die + Take Off/Landing + effects
- Kraken — Body: Idle, Swim, Attack, Dmg, Die + Appear/Disappear. Tentacles (separate): Idle, Attack, Dmg, Die + Appear/Disappear
- Medusa — Idle, Walk, Attack, Attack2, Dmg, Die + Props
- Naga — standard combat set
- Phoenix — Idle, Fly (on fire/normal), Dmg (on fire/normal), Die (on fire/normal) + Egg Idle + Reborn + Fire Ignition/Extinction
- Sandworm — Idle, Dmg, Die + Emerge/Submerge/Jump + Sand Hole/Splash effects
- Spider Queen — Idle, Walk, Attack, Dmg, Die + Web Shot (diagonal/orthogonal) + Web Projectiles

**Humanoid Enemies & NPCs:**
- Ancient Danger — Idle, Walk, Attack (melee), Dmg, Die + Ranged (diagonal/orthogonal) + Energy Explosion/Projectile + Glow
- Ancient Danger Heavy Warrior — standard combat set + Shot (diagonal/orthogonal) + Projectile/Impact + Glow
- Ancient Danger Leader — Idle, Walk, Attack + Impact, Dmg, Die
- Ancient Danger Scarab — Idle, Walk, Attack + effect, Dmg, Die + Glow
- Armored Warrior — Idle, Walk, Attack, Charging, Dmg, Die
- Combat Sister — Idle, Walk, Dmg, Die + Melee Attack + Shot (diagonal/orthogonal)
- Cultists — Bronze and Green variants. Standard set (Idle/Walk/Attack/Dmg/Die as separate folders)
- Farmer — Idle, Walk, Walk2, Attack, Dmg, Die + Hoe/WateringCan work animations
- Goblin Catapult — Idle, Move, Dmg, Die + Shot (goblin/rock variants) + Goblin Landing/Projectile + Rock Impact/Projectile
- Goblin King — Idle (3-phase), Walk, Attack, Dmg, Die
- Goblin Raider — 2 variants (with/without torch). Standard combat set
- Goblin Sapper — Idle, Run, Dmg, Die + Only_Bomb (explosion sprite)
- Hunter — standard combat set
- King — Idle, Walk, Attack, Dmg, Die + Behead Die (+ gore variant)
- Lumberjack — standard combat set + WoodCutting
- Merchant — Idle, Walk, Dmg, Die + Stall Setup/Idle/PackBack
- Miner — standard combat set + Mining action
- Orc Knight — Idle, Gallop, Dmg + effect, Die + effect
- Orc Shaman — Idle, Walk, Dmg, Die + Put Totem (Fire/Heal/Ice) + Totems (Appear/Disappear/status) + effects
- Samurai — standard combat set + separate attack effect
- Town Guards — Human/Elf/Dwarf/Orc variants. Standard combat set
- Travelling Merchant — On Foot + On Cart variants. Standard set
- Wise Orc — standard combat set
- Pit Warriors — standard combat set + Net Throw

**Fey & Forest:**
- Elf Druid — Idle, Walk, Dmg, Die + Cast Spell + Summon Spell + Wind Swirl + effects
- Mushroom People — Idle, Jump, Dmg + effect, Die + effect. No attack
- Naughty Fairy — Fly/Idle, Dmg + effect, Die/Disappear + Appear + Spread Dust + Transformation Effect
- Swamp Witch — Idle, Walk, Fly, Attack, Dmg, Die + Frog Curse + Frog Transformation + Ride. Has companion Green Frog sub-unit
- Tree Spirits — expanded: Idle, Walk, Dmg, Die + Heal + PlantSeed + Sapling + Wakeup (7 animation types)
- Will-O-Wisp — Idle, Floating, Attack, Dmg, Die + Projectile/Collision Effect

**Desert & Tomb:**
- Lesser Mummy — Idle, Walk, Attack + effect, Dmg + effect, Die + effect
- Mummy King — Idle, Walk, Attack + effect, Dmg + effect, Die + effect

**Aquatic:**
- Frogfolk — Warrior (Idle, Walk, Jump, Attack, Dmg, Die) + Villager (Idle, Walk, Jump, Dmg, Die)
- Lizardmen — 3 types: Lizard, Saurus, Skink. All standard combat sets
- Otter — Idle, Walk, Swim, Bite, Dmg, Die + Ranged (diagonal/orthogonal) + Stone Projectile/Impact

**Divine/Celestial:**
- Divine Angel — Idle, Fly, Attack, Dmg, Die + Summon/Unsummon
- Divine God — Idle/Fly, Melee Attack, Dmg + Appear/Disappear + Divine Wrath (summon/spell) + Glow
- Divine Guardian — Idle, Fly, Attack, Dmg, Die + Summon/Unsummon + effects
- Divine Warden — Idle, Fly, Dmg, Die + Shot (diagonal/orthogonal) + Projectile/Impact + Summon/Unsummon

**Misc Fantasy:**
- Ancient Troll — Idle, Walk, Attack, Dmg, Die + Eat animation
- Ballista Emplacement — Aim, Reload, Shot (diagonal/orthogonal) + Projectile + Dmg variants. Siege weapon
- Dwarven Marksman — Idle, Walk, Dmg, Die + Reload + Shot (diagonal/orthogonal) + Impact + Set Trap/Trap Triggered
- Gnomes — Premade variants + Separate Layers for customization
- Mad Inventor — Idle, Walk, Attack, Dmg, Die + BluePrint animation
- Slime Cube (Large) — Idle, Walk/Attack, Dmg, Die + Divide (splits into small). Has Trapped Skeleton variant
- Slime Cube (Small) — Idle, Walk/Attack, Dmg, Die
- Ursaling — Folk and Warrior variants

**Sci-fi (thematically incompatible, but available):**
- Alien Bio Horror, Astronaut, Gnome Gyrocopter, Modern Soldiers, Reliquary Combat Armor, Space Hunter, Space Orc (+Boss), Tech Priest, War Servitor

**Seasonal (holiday-themed):**
- Evil Pumpking, Evil Snowman (upgraded w/ projectiles), Evil Windup Teddy Bear, Grumpus, Headless Horseman, Krampus, Nutcracker, Rudolph, Santa (+Helper), Giant Turkey

### Patreon Addon Packs

Extensions to existing environment/tileset packs. Source: `All_Exclusives_20260409/Addons/`.

| Base Pack | Addon Content |
|---|---|
| Ancient Forests | Druid's Shrine tileset |
| Castles & Strongholds | Damaged Castle tileset |
| Crafting & Professions | Belts/Pants/Gloves/Cloaks, Carrying Animations, Cartographer/Fletcher/Painter/Staves workshops, Gold/Rock/Hellscape Mineral Nodes, Growing Trees, Material Piles, More Fish, More Food Recipes |
| Crypt of the Forgotten | More Lovecraftian Statues, Ossuary Skeleton Spawn Point |
| Deep Caves | Cenote, Glowing Mushrooms, New Hills, Old Mine |
| Desolate Desert | Giant Bones, New Hills, Pyramids, Sand Dunes |
| Dungeon | Entrances, Lava Pit, Traps, Levers & Switches, Sacrifice Altars |
| Dwarven Kingdom | Lava Forge |
| Farm | Cart (animated), Farming Animations (Plowing/Seeding/Watering), Fruit Trees, More Veggies |
| Forgotten Plains | Ancient Statues, Bush Berries, Colossus Statue Remains, Extended Cliff, Floating Islands, More Grass, New Hills, Shallow Water, Tall Grass, Wall of Trees |
| Icy Wilderness | Frost Bite Site, Winter Tree Variations |
| Medieval Carnival | Caravans & Wagons, Knight Jousting, Monster Balloon Stall |
| Medieval City | Ruined Stone House, Shop Signs |
| Mounts | Undead Dragon Mount |
| Raided Village | Slate Roof & Humble Chimney |
| Ships & Docks | Shipwreck Props, Small Boats tileset |
| Silent Swamp | Frogfolk Settlement, Giant Mushrooms |
| Spell Effects | Super Tier Magic, Water Spell Tsunami |
| Tiny Overworld | Mountain Ranges, Ships & Docks tileset, Tiny Weather Effects, Upgradeable Tiny Buildings |
| Towns I & II | Animated Well, Church, Gladiator Arena, Hen Nests, Horse Stables, Plant Pots, Shop Indoor, Tavern Indoor, Fountains, Monuments, Ruins, Wooden Bridge |
| Warp Lands | Opening & Closing Reality Cracks |
| Weapons | Crossbow, Diagonal Attacks, Orthogonal Sword Attack, Unarmed |
| Wizards Academy | Chamber of Secrets |
| User Interface | Animated UI Book, Shop UI, TCG UI |

**Miscellaneous Addons** (not tied to a specific pack):
8x8 Flags, Astronomical Observatory, Bamboo Forest, Barracks Props, Biome Transitions, Cage Traps, Chests, Crater, Crawl/Dance/Sleeping Animations, Dolmens, Giant Sword, Gold Prospector Camp, Green House, Helmet Designs, Hole Entrances & Ropes, Magical Bonfires, Magic Gateway, Magic Portals, More Signage, Outdoor Lanterns, Piles of Loot, Pop Culture Characters, Raft, Rope Bridge, Skull Hideout, Stargate, Totems, Tree Animations (Wind), Tree Variations, Volcano, Wearable Backpacks, Weather Effects, Wizard Tower, Wooden Hut

### Patreon Seasonal Environment Packs

Full tileset+props packs. Source: `All_Exclusives_20260409/Seasonal_Content/`.

- **Adventurer's Campsite** — campsite tileset + animations
- **Beach Village** — coastal village tileset + props + premade scene
- **Haunted House** — haunted house tileset + props
- **Lunar New Year Festival** — festival tiles + props + firecrackers + flying lantern + Tiger creature
- **More Dungeons** — Ancient Ruins Dungeon, Ice Dungeon, Torture Dungeon
- **Snowball Wars** — snow tileset + characters + props + snowball projectiles
- **Spooky Graveyard** — Classic + Night variants, full tileset + props
- **Summer Holidays** — beach tileset + characters + props

### Patreon Icon Sets

Source: `All_Exclusives_20260409/Icons/`.

**8x8px Icon Sets (34 sets):**
Adventurer Gear, Biome, Body Part, Chess, Container, Creature-Type, Creature, Druid Skill, Fishing Gear, Farm Animal Product, Hero Class Armour, Hero Class, Home, Illness & Ailment, Item Upgrade/Downgrade, Junk Loot, Legendary Set, Lockpicking, Loot, Medicine, Minigames & Gambling, Musical Instrument, Ninja Tool, Profession, Racial, Rank, Religion, Space Derelict, Spell, Stat, Status Effect, Train, True Heroes 2, Written Stuff, Miscellany (Coins/Torches/MMO UI/etc.)

**16x16px Icon Sets:**
- True Heroes I & II skill icons
- True Heroes III & IV skill icons

---

## Palette Swapping

Any sprite can be duplicated into a variant class via palette swap tool (`tools/palette_swap.py`) for pre-baked file variants, or via Godot CanvasItem shaders for runtime remapping. At 8x8 with ~6-8 colors per sprite, a palette swap is just remapping a handful of values. This massively expands the effective roster from every sprite tier, not just A-list.

### Executed Palette Swaps

#### Demonologist → Witch Doctor (Red → Shadow Purple)

**Reference palette:** Shadow Magic effects pack (`assets/effects/shadow/`), which uses a consistent 3-color scheme: `#452555` (dark violet H:280), `#873f72` (purple-magenta H:317), `#d22727` (red accent H:0).

**Tool command:**
```
python tools/palette_swap.py swap <input> --hue-range 324 30 --min-sat 0.60 --palette c050d0 9a3cb0 7a3090 5e2570 452555 301840 -o <output>
```

**Parameters:**
- `--hue-range 324 30` — wraps around 0° to capture all reds (H:324–360–0–30) including magentas and crimsons
- `--min-sat 0.60` — excludes brown skin tones (S:0.14–0.48) and the dark face shadow `#672d2d` (S:0.56) while catching all clothing reds (S:0.81–1.00)

**Target palette (6 colors, sorted by luminance):**
| Hex | H | S | V | Role |
|---|---|---|---|---|
| `#301840` | 276° | 0.62 | 0.25 | Deepest shadow |
| `#452555` | 280° | 0.56 | 0.33 | Dark base (matches shadow FX pack) |
| `#5e2570` | 286° | 0.67 | 0.44 | Mid-dark |
| `#7a3090` | 286° | 0.67 | 0.56 | Mid |
| `#9a3cb0` | 289° | 0.66 | 0.69 | Mid-bright |
| `#c050d0` | 293° | 0.62 | 0.82 | Highlight |

**What stays untouched:** Skin tones (#ffa499, #ad846d, #865346, #9f9189), neutral grays/blacks, cyan/azure clothing details, the dark face shadow #672d2d. Demon summon sprites were copied as-is (not recolored).

**To match additional sprites to this scheme:** Use the same `--hue-range 324 30 --min-sat 0.60 --palette c050d0 9a3cb0 7a3090 5e2570 452555 301840` parameters. The tool auto-maps source colors to target by nearest luminance, so it handles varying numbers of source reds gracefully.

---

## Notes

- All sprites are 8x8 pixel art, 4-directional (NW-NE-SW-SE).
- **Only E/W directions are used in-game.** The game is side-scrolling — all animations (walk, attack, idle, etc.) use the SE row (facing right). Facing left is achieved by flipping the sprite horizontally. The NW/NE/SW rows in each sprite sheet are unused. This applies to heroes, enemies, summons, and effects.
- **Frame sizes vary between character sprites and effect sprites.** Character animations are typically 32×32. Effect animations are often 64×64. Always check the source pack's AnimationInfo.txt for the actual frame dimensions before extracting.
- **Some assets are directional grids, not animation strips.** Projectile sprites (e.g. Fireball_Projectile.png, 96×96) contain 8 static directional sprites in a 3×3 grid — these are NOT animation frames. Extract the single cell for the direction needed.
- At 8x8 resolution, Hans can create supplemental sprites if needed.
- The modular NPC system (Myriad of NPCs) can fill gaps for classes that don't match any pre-made sprite.
- Summon sprites (Spirit Guardian, Fire Familiar, Blood Elemental, Angry Demon, Skeletal Champion) are available as standalone animated units.
