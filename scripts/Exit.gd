extends Node2D

onready var exit_particles = $ExitParticles
onready var explode_particles = $ExplodeParticles

func destroy():
	exit_particles.emitting = false
	explode_particles.emitting = true
