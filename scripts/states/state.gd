# Design Ref: §3.5 — FSM 상태 베이스. 각 상태는 이 클래스를 상속한다.
extends Node

var pet: Node2D          # scenes/pet/pet.gd
var machine: Node        # scenes/pet/state_machine.gd


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass
