# 놀기: 신나게 뛰어다니는 리액션 (FR: 케어 '놀기' 시각 피드백) 후 Idle 복귀.
extends "res://scripts/states/state.gd"

var _timer := 0.0
var _use_animated_play := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	_timer = 2.6
	# 놀기 전용 다중 프레임 시트(happy 시트)가 있는 종족은 그쪽을 쓴다. 시트가 깡충임과
	# 날개 파닥임을 직접 그리므로 좌표/회전 트윈(play_frolic)은 쓰지 않는다 — 겹치면
	# 프레임별 발 위치(foot_padding)가 무시된 곳에서 멈춘다.
	_use_animated_play = pet.start_animated_pose("Play")
	if not _use_animated_play:
		pet.set_pose("happy")
	# play_frolic()은 시트 재생 중이면 내부에서 트윈을 건너뛰고 "신난다~♪" 말풍선만 띄운다.
	pet.play_frolic()


func exit() -> void:
	if _use_animated_play:
		pet.stop_animated_pose()
		_use_animated_play = false
	pet.reset_sprite_pose()
	pet.set_pose("idle")


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
