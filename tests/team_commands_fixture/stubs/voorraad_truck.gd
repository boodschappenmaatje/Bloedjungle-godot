class_name VoorraadTruck
extends Node3D
## Stub voor de fixture: alleen wat ally.gd (ingenieur) nodig heeft om te compileren.

enum S { WACHT, HEEN, LADEN, TERUG, LOSSEN, WRAK }
const HP_MAX := 400.0
var state := S.WACHT
var hp := HP_MAX
