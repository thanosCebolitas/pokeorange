--------------------------------------------------------------------------------
## Suggested Team Updates
--------------------------------------------------------------------------------

### Improved E4 Teams

#### Bruno
ONIX, HITMONCHAN, HITMONLEE, ONIX, MACHAMP

#### LoreleiData:
DEWGONG, CLOYSTER, SLOWBRO, JYNX, LAPRAS
-> Jynx, Lapras, Cloyster, Articuno

#### AgathaData:
GENGAR, GOLBAT, HAUNTER, ARBOK, GENGAR

#### LanceData:
GYARADOS, DRAGONAIR, DRAGONAIR, AERODACTYL, DRAGONITE

--------------------------------------------------------------------------------
### Improved Gym Leader Teams
--------------------------------------------------------------------------------

#### Brock
Geodude, Onix, Rhyhorn, Kabuto, Omanyte, Aerodactyl

#### Misty
Starmie, Cloyster, Slowbro, Gyarados, Lapras, Tentacruel/Blastoise

#### Lt. Sarge
Raichu, Jolteon, Zapdos, Electabuzz, Electrode, Magneton

#### Erika
Exeggutor, Tangela, Venusaur, Victreebel, Parasect, Vileplume

#### Sabrina
Alakazam, Hypno, Exeggutor, Starmie, Slowbro, Jynx

#### Blackbelt
Hitmonchan, Hitmonlee, Machamp, Poliwrath, Primeape, ??

#### Koga
Gengar, Tentacruel, Arbok, Nidoking, Nidoqueen, Venomoth

#### Blaine
Ninetales, Charizard, Flareon, Moltres, Arcanine, Rapidash

#### Giovanni
Dugtrio, Rhydon, Nidoking, Nidoqueen, Sandslash, Golem

--------------------------------------------------------------------------------
### Improved Rival Teams
--------------------------------------------------------------------------------

#### Rival1
#### Rival2
#### Rival3

--------------------------------------------------------------------------------
### Improved Other Teams
--------------------------------------------------------------------------------

#### ProfOak
#### Youngster
#### BugCatcher
#### Lass
#### Sailor
#### JrTrainerM
#### JrTrainerF
#### Pokemaniac
#### SuperNerd
#### Hiker
#### Biker
#### Burglar
#### Engineer
#### Fisher
#### Swimmer
#### CueBall
#### Gambler
#### Beauty
#### Psychic
#### Rocker
#### Juggler
#### Tamer
#### BirdKeeper
#### Scientist
#### Rocket
#### CooltrainerM
#### CooltrainerF
#### Gentleman

--------------------------------------------------------------------------------
## Suggested Wild Pokemon Locations
--------------------------------------------------------------------------------

#### Pallet
#### Route 1
#### Route 22
#### Route 2
#### Viridian Forest
#### PewterCity [Brock]
#### Route 3
#### Mt. Moon
#### Route 4
#### Cerulean City [Misty]
#### Route 24
#### Route 25
#### Route 6
#### Route 11
#### Vermillion City [Lt. Sarge]
#### SS. Anne
#### Diglet's Cave
#### Route 9
#### Lavender Town
#### Pokemon Tower
#### Route 12
#### Route 8
#### Route 7
#### Celadon City [Erika]
#### Saffron City [Sabrina] [Blackbelt]
#### Route 13
#### Route 14
#### Route 15
#### Route 16
#### Route 17
#### Route 18
#### Fuchsia City [Koga]
#### Safari Zone
#### Power Plant
#### Route 19
#### Seafoam Islands
#### Route 20
#### Cinnabar Island
#### Pokemon Mansion
#### Route 21
#### Route 23
#### Victory Road

--------------------------------------------------------------------------------
## Suggested TM Mart Locations
--------------------------------------------------------------------------------

#### CERULIAN MART

TM34	Bide	Pewter City - Gym
TM12	Water Gun	Mt. Moon
TM04	Whirlwind	Route 4

#### VERMILLION MART

TM11	Bubble Beam	Cerulean City - Gym
TM19	Seismic Toss	Route 25
TM28	Dig	Cerulean City
TM30	Teleport	Route 9
TM45	Thunder Wave	Route 24

#### LAVENDER MART

TM08	Body Slam	S.S. Anne
TM24	Thunderbolt	Vermilion Gym
TM44	Rest	S.S. Anne
TM42	Dream Eater	Viridian City

#### SAFFRON MART

TM03	Sword's Dance	Silph Co.
TM26	Earthquake	Silph Co.
TM36	SelfDestruct	Silph Co.
TM13	Ice Beam	Celadon City Store Roof
TM18	Counter	Celadon City Store
TM21	Mega Drain	Celadon City - Gym
TM41	Softboiled	Celadon City
TM48	Rock Slide	Celadon City Store
TM49	Tri Attack	Celadon City Store

#### FUCSHIA MART

TM10	Double Edge	Game Corner
TM29	Psychic	Saffron City
TM31	Mimic	Saffron City
TM46	Psywave	Saffron City - Gym

#### CINNABAR MART

TM16	Pay Day	Route 12
TM20	Rage	Route 15
TM39	Swift	Route 12
TM06	Toxic	Fuchsia City - Gym
TM25	Thunder	Power Plant
TM40	Skull Bash	Safari Zone

#### INDIGO MART

TM35	Metronome	Cinnabar Island
TM38	Fire Blast	Cinnabar Island - Gym
TM14	Blizzard	Pokémon Mansion
TM22	Solar Beam	Pokémon Mansion

TM27	Fissure	Viridian City - Gym
TM43	Sky Attack	Victory Road
TM47	Explosion	Victory Road

#### Already available TMs

TM01	Mega Punch	Mt. Moon / Celadon City Store
TM02	Razor Wind	Celadon City Store
TM05	Mega Kick	Victory Road / Celadon City Store
TM07	Horn Drill	Celadon City Store
TM09	Take Down	Saffron City / Celadon City Store
TM17	Submission	Victory Road / Celadon City Store
TM32	Double Team	Fuchsia City / Celadon City Store
TM33	Reflect	Power Plant / Celadon City Store
TM37	Egg Bomb	Fuchsia City / Celadon City Store

TM15	Hyper Beam	Celadon City - Game Corner
TM23	Dragon Rage	Celadon City - Game Corner
TM50	Substitute	Celadon City - Game Corner

--------------------------------------------------------------------------------
## Gym Leader AI
--------------------------------------------------------------------------------

SelectAction::
- Is this pkmn good enough? 							[IsPKMNGoodEnough]
	- If not, is there a better choice?					[IsThereABetterPKMNMatch]
		- If not, jmp to PickAMove
		- If yes, switch to that
	- If yes, go on
.PickAMove
- Are we about to die?									[IsPKMNAboutToDie]
	- If so, do we have a healing move?					[HasHealingMove]
		- If yes, do that
		- If not, go on
- Has enemy any non-volatile statuses?					[EnemyHasNonVolatileStatus]
	- If yes, jmp to .shouldApplyVolatileStatus
	- If not, do we have a status inflicting move?		[HasStatusInflictingMove]
		- If yes, do that
		- If not, go on
.shouldApplyVolatileStatus
- Can we apply volitile status?							[CanApplyVolitileStatus]
	- If yes, do that
	- If not, go on
.shouldImproveDefence
- Can we improve defense meaningfully?					[ShouldImproveDefence]
	- If yes, do that
	- If no, go on
.DoDMG
- Do we play first?										[PKMNPlaysFirst]
	- If yes, will any move KO most probably?			[WillAMoveKO]
		- If yes, do that
		- If not, go on
	- If not, go on
- Do we have fly or dig?								[HasFlyOrDig]
	- If yes, do that
	- If not, go on
- Pick move that does most dmg 							[PickMoveThatDoesMostDMG]


IsPKMNGoodEnough::

IsThereABetterPKMNMatch::

IsPKMNAboutToDie::

HasHealingMove::

EnemyHasNonVolatileStatus::

HasStatusInflictingMove::

CanApplyVolitileStatus::

ShouldImproveDefence::

PKMNPlaysFirst::

WillAMoveKO::

HasFlyOrDig::

PickMoveThatDoesMostDMG::
