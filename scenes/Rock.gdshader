shader_type canvas_item;

uniform vec4 outline_col :hint_color; //Outline color
uniform bool outline_on = false;

bool approx_eq(vec4 c1, vec4 c2) { return all( lessThan( abs( c1 - c2 ), vec4( 0.005, 0.005, 0.005, 0.005) ) ); }

void fragment() {

	vec4 col = texture(TEXTURE,UV);

	if (col == vec4(1,1,1,1) || approx_eq(col, vec4(0.53, 0.53, 0.53, 1)) || approx_eq(col, vec4(0.75, 0.75, 0.75, 1))) {
	    COLOR *= texture(TEXTURE, UV);
	} else if (!outline_on) {
		COLOR = col;
	} else {
		//Get alpha val of adjacent pixels

		vec2 p = TEXTURE_PIXEL_SIZE;

		float a = texture(TEXTURE,UV+vec2(p.x,0)).a;

	    a += texture(TEXTURE,UV+vec2(-p.x,0)).a;

	    a += texture(TEXTURE,UV+vec2(0,p.y)).a;

	    a += texture(TEXTURE,UV+vec2(0,-p.y)).a;

	//Using found alpha value,

	    a = step(a,.5);//Clamp the a value

	    col.rgb = mix(outline_col.xyz, col.rgb, col.a);

	    col.a = step(a, col.a);

	//Get palette color

	    COLOR = col;
	}
}