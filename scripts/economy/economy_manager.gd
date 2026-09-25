extends Node
## Same passive income for all teams. Workers additionally sell each wood for $1.

var teams: Array[GameTeam] = []
var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	while elapsed >= 1.0:
		elapsed -= 1.0
		for team in teams:
			team.add_resources(int(team.get_stat(&"income")))
