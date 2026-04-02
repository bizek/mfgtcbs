@tool
extends Control

## Records panel — lifetime stat display.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase
@onready var _total_runs:      Label = $PanelBase/ContentContainer/TotalRunsLabel
@onready var _extractions:     Label = $PanelBase/ContentContainer/ExtractionsLabel
@onready var _deaths:          Label = $PanelBase/ContentContainer/DeathsLabel
@onready var _kills:           Label = $PanelBase/ContentContainer/KillsLabel
@onready var _deepest_phase:   Label = $PanelBase/ContentContainer/DeepestPhaseLabel
@onready var _most_loot:       Label = $PanelBase/ContentContainer/MostLootLabel
@onready var _divider:         Label = $PanelBase/ContentContainer/DividerLabel
@onready var _extraction_rate: Label = $PanelBase/ContentContainer/ExtractionRateLabel

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)

func populate(pm: Node) -> void:
	_total_runs.text      = "Total Runs:          %d" % pm.total_runs
	_extractions.text     = "Extractions:         %d" % pm.successful_extractions
	_deaths.text          = "Deaths:              %d" % pm.deaths
	_kills.text           = "Total Kills:         %d" % pm.total_kills
	_deepest_phase.text   = "Deepest Phase:       %d" % pm.deepest_phase
	_most_loot.text       = "Most Loot (run):     %d" % int(pm.most_loot_extracted)

	var rate: String
	if pm.total_runs > 0:
		rate = "%d%%" % int(float(pm.successful_extractions) / float(pm.total_runs) * 100.0)
	else:
		rate = "\u2014"
	_extraction_rate.text = "Extraction Rate:     %s" % rate
