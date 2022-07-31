package rayke

import strconv "core:strconv"
import strings "core:strings"
import fmt "core:fmt"
import "core:unicode/utf8"
import math "core:math"

import rl "vendor:raylib"
import jass "jass"

Timer :: struct {current_time : f32, total_time : f32,}
count_timer_up :: proc(timer: ^Timer) { if timer.current_time <= timer.total_time && timer.current_time >= 0 {timer.current_time += rl.GetFrameTime()}}
count_timer_down :: proc(timer: ^Timer) { if timer.current_time >= 0 { timer.current_time -= rl.GetFrameTime() } }
reset_timer :: proc(timer: ^Timer) { timer.current_time = timer.total_time}

Console :: struct
{
	line : [dynamic]rune,

	up_pos : rl.Vector2,
	down_pos : rl.Vector2,

	start_pos: rl.Vector2,
	current_pos : rl.Vector2,
	end_pos : rl.Vector2,

	font: rl.Font,
	font_size: i32,
	
	move_timer: Timer,
	repeat_timer: Timer,
}

make_console :: proc(screen_width, screen_height, font_size: i32, font: rl.Font) -> Console
{	
	line : [dynamic]rune

	up_pos : rl.Vector2 = {0.0, f32(-screen_height)}
	down_pos : rl.Vector2 = {0.0, 0.0}

	start_pos: rl.Vector2 = down_pos
	current_pos : rl.Vector2 = up_pos
	end_pos : rl.Vector2 = up_pos

	move_timer : Timer = {0.0, 0.1}
	repeat_timer : Timer = {0.0, 0.1}

	console: Console = 
	{
		line,
		up_pos,
		down_pos,

		start_pos,
		current_pos,
		end_pos,
		font,
		font_size,

		move_timer,
		repeat_timer,
	}
	return console
}

draw_console :: proc(console: ^Console, screen_width, screen_height: i32)
{
	console_background_color : rl.Color = {30, 30, 30, 180}
	rl.DrawRectangleV(console.current_pos, {f32(screen_width), f32(screen_height)}, console_background_color)
	draw_parameter_stack(console)
	draw_input_line(console)
	draw_log(console)
}

draw_parameter_stack :: proc (console: ^Console)
{
	param_pos_x : i32 = 10 + i32(console.current_pos.x)

	params := "stack: "
	draw_text_with_shadow(params, {f32(param_pos_x), console.current_pos.y + 5}, rl.MAROON, console.font, f32(console.font_size))
	param_pos_x += rl.MeasureText(strings.clone_to_cstring(params), console.font_size + 5)

	for param in jass.stack 
	{	
		param_string : string
		switch v in param
		{
			case f32:
			param_string = fmt.tprintf("%f", param)
			
			case string:
			param_string = v
		} 
		param_width := rl.MeasureText(strings.clone_to_cstring(param_string), console.font_size)

		text_pos : rl.Vector2 = {f32(param_pos_x), console.current_pos.y + 5}
		draw_text_with_shadow(param_string, text_pos, rl.WHITE, console.font, f32(console.font_size))
		param_pos_x += param_width + 20
	}
}

draw_log :: proc(console: ^Console)
{
	log_position : rl.Vector2 = console.current_pos + {10, f32(console.font_size) + 50}
	for entry in jass.log
	{	
		draw_text_with_shadow(entry, log_position, rl.DARKGRAY, console.font, f32(console.font_size))
		log_position.y += f32(console.font_size) + 5
	}
}

draw_text_with_shadow :: proc(text: string, position: rl.Vector2, color: rl.Color, font: rl.Font, font_size: f32)
{
	draw_position := position
	text_to_draw := strings.clone_to_cstring(text)
	drop : f32 = 2
	rl.DrawTextEx(font, text_to_draw, draw_position + {drop, drop}, font_size, 1, rl.BLACK)
	rl.DrawTextEx(font, text_to_draw, draw_position, font_size, 1, color)
}

draw_input_line :: proc(console: ^Console)
{
	draw_pos := console.current_pos + {10, 50}
	params := "> "
	draw_text_with_shadow(params, draw_pos, rl.MAROON, console.font, f32(console.font_size))

	draw_pos += {f32(rl.MeasureText(strings.clone_to_cstring(params), console.font_size) + 2), 0}

	linestring := utf8.runes_to_string(console.line[:])
	draw_text_with_shadow(linestring, draw_pos, rl.GRAY, console.font, f32(console.font_size))
}

drop_console_down :: proc(console: ^Console)
{
	console.start_pos = console.up_pos
	console.end_pos = console.down_pos
	reset_timer(&console.move_timer)
}

roll_console_up :: proc(console: ^Console)
{
	console.start_pos = console.down_pos
	console.end_pos = console.up_pos
	reset_timer(&console.move_timer)
}

sim_console :: proc (console: ^Console)
{
	count_timer_down(&console.move_timer)
	percent := clamp(console.move_timer.current_time / console.move_timer.total_time, 0, 1)
	eased := rl.EaseCubicIn(percent, 0, 1, 1)
	console.current_pos = math.lerp(console.end_pos, console.start_pos, eased)
}

is_console_down :: proc (console: ^Console) -> bool { return console.end_pos == console.down_pos }
is_console_up :: proc (console: ^Console) -> bool { return console.end_pos == console.up_pos }


handle_input :: proc (console: ^Console)
{
	sim_console(console)

	if is_console_down(console) && console.move_timer.current_time <= 0
	{
		if rl.IsKeyPressed(rl.KeyboardKey.GRAVE) { roll_console_up(console) }

		key := rl.GetCharPressed()
		for key > 0
		{
			if (key >= 32) && (key <= 125) && (key != '`')
			{
				append(&console.line, key)
			}
			key = rl.GetCharPressed()  // Check next character in the queue
		}

		count_timer_down(&console.repeat_timer)
		if rl.IsKeyDown(rl.KeyboardKey.BACKSPACE)
		{
			if len(console.line) > 0 && console.repeat_timer.current_time <= 0
			{
				pop(&console.line)
				reset_timer(&console.repeat_timer)
			}
		}

		if rl.IsKeyPressed(rl.KeyboardKey.UP)
		{
			if len(jass.log) > 0
			{
				prev_line := utf8.string_to_runes(jass.log[len(jass.log) - 1])
				for character in prev_line
				{
					append(&console.line, character)
				}
			}
		}

		if rl.IsKeyPressed(rl.KeyboardKey.ENTER)
		{
			line_string := utf8.runes_to_string(console.line[:])
			jass.run_line(line_string)
			append(&jass.log, line_string)
			for len(console.line) > 0
			{
				pop(&console.line)
			}
		}
	}

	if is_console_up(console) && console.move_timer.current_time <= 0
	{
		if rl.IsKeyPressed(rl.KeyboardKey.GRAVE) { drop_console_down(console) }	
	}
}
