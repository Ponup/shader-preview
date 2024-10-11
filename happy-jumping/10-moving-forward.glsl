#version 410 core

out vec4 FragColor;

uniform float time;
uniform int mouseX, mouseY;
uniform int resolutionX, resolutionY;

// smooth min
float smin(in float a, in float b, float k) {
    float h =  max(k - abs(a-b), 0.0);
    return min(a,b) - h * h *0.25/k;
}

vec2 smin(vec2 a, vec2 b, float k) {
    float h = clamp(0.5 + 0.5 * (b.x-a.x)/k, 0, 1);
    return mix(b, a, h) - k*h*(1-h);
}

// smooth max
float smax(in float a, in float b, float k) {
    float h =  max(k - abs(a-b), 0.0);
    return max(a,b) + h * h * 0.25/k;
} 

float sdSphere(in vec3 pos, float rad) {
    return length(pos) - rad;
}

vec2 sdStick(in vec3 p, vec3 a, vec3 b, float ra, float rb) {
    vec3 ba = b-a;
    vec3 pa = p-a;
    float h = clamp(dot(pa, ba)/dot(ba,ba), 0, 1);
    float r = mix(ra, rb, h);
    return vec2(length(pa - ba*h) - mix(ra, rb, h*h*(3-2*h)), h);
}

vec2 opU(vec2 d1, vec2 d2) {
    return (d1.x<d2.x) ? d1 : d2;
}

float sdEllipsoid(in vec3 pos, vec3 rad) {
    float k0 = length(pos/rad);
    float k1 = length(pos/(rad*rad));
    return k0*(k0-1)/k1;
}


vec2 map( in vec3 pos, float atime )
{
    float t1 = fract(atime);

    float p = 4.0*t1*(1.0-t1);
    float pp = 4.0*(1.0-2.0*t1);

    vec3 cen = vec3( 0.0,
                     p + 0.1,
                     time );
    // body
    vec2 uu = normalize(vec2( 1.0, -pp ));
    vec2 vv = vec2(-uu.y, uu.x);
    
    float sy = 0.5 + 0.5*p;
    float compress = 1.0-smoothstep(0.0,0.4,p);
    sy = sy*(1.0-compress) + compress;
    float sz = 1.0/sy;

    vec3 q = pos - cen;
    vec3 r = q;
	
    q.yz = vec2( dot(uu,q.yz), dot(vv,q.yz) );
    
    vec2 res = vec2( sdEllipsoid( q, vec3(0.25, 0.25*sy, 0.25*sz) ), 2.0 );

    float t2 = fract(atime+0.8);
    float p2 = 0.5-0.5*cos(6.2831*t2);
    r.z += 0.05-0.2*p2;
    r.y += 0.2*sy-0.2;
    vec3 sq = vec3( abs(r.x), r.yz );

	// head
    vec3 h = r;
    vec3 hq = vec3( abs(h.x), h.yz );
   	float d  = sdEllipsoid( h-vec3(0.0,0.20,0.02), vec3(0.08,0.2,0.15) );
	float d2 = sdEllipsoid( h-vec3(0.0,0.21,-0.1), vec3(0.20,0.2,0.20) );
	d = smin( d, d2, 0.1 );
    res.x = smin( res.x, d, 0.1 );
        
    // ears
    {
    float t3 = fract(atime+0.9);
    float p3 = 4.0*t3*(1.0-t3);
    vec2 ear = sdStick( hq, vec3(0.15,0.32,-0.05), vec3(0.2+0.05*p3,0.2+0.2*p3,-0.07), 0.01, 0.04 );
    res.x = smin( res.x, ear.x, 0.01 );
    }
    
    // mouth
    {
   	d = sdEllipsoid( h-vec3(0.0,0.15+4.0*hq.x*hq.x,0.15), vec3(0.1,0.04,0.2) );
    res.x = smax( res.x, -d, 0.03 );
    }
        
    // eye
    {
    float blink = pow(0.5+0.5*sin(2.1*time),20.0);
    float eyeball = sdSphere(hq-vec3(0.08,0.27,0.06),0.065+0.02*blink);
    res.x = smin( res.x, eyeball, 0.03 );
    
    vec3 cq = hq-vec3(0.1,0.34,0.08);
    cq.xy = mat2x2(0.8,0.6,-0.6,0.8)*cq.xy;
    d = sdEllipsoid( cq, vec3(0.06,0.03,0.03) );
    res.x = smin( res.x, d, 0.03 );

    res = opU( res, vec2(sdSphere(hq-vec3(0.08,0.28,0.08),0.060),3.0));
    res = opU( res, vec2(sdSphere(hq-vec3(0.075,0.28,0.102),0.0395),4.0));
    }
        
    // ground
    {
        float fh = -0.1 + 0.05*(sin(2*pos.x)+sin(2*pos.z));
        d = pos.y - fh;
        if( d<res.x ) res = vec2(d,1.0);
    }
   
    
    return res;
}

vec3 calcNormal(in vec3 pos, float time) {
    vec2 e = vec2(0.0001, 0);
    return normalize(vec3(map(pos + e.xyy, time).x - map(pos-e.xyy, time).x,
                        map(pos + e.yxy, time).x - map(pos-e.yxy, time).x,
                        map(pos + e.yyx, time).x - map(pos-e.yyx, time).x)
                        );
}
float castShadow(in vec3 ro, vec3 rd) {
    float res = 1;

    float t = 0.001;
    for(int i =0; i <100; i++) {
        vec3 pos = ro + t*rd;
        float h = map(pos, time).x;
        res= min(res, 16*h /t);
        if(h<0.0001) break;
        t+=h;
        if(t>20) break;

    }
    return clamp(res, 0, 1);
}

vec2 castRay( in vec3 ro, vec3 rd, float time) {
    vec2 res = vec2(-1,-1);
    float tmin = 0.5;
    float tmax = 20;

    float t = tmin;
    for(int i = 0; i < 512 && t<tmax; i++) {
        vec2 h = map(ro+rd*t, time);
        if(h.x < 0.001) {
            res = vec2(t,h.y);
            break;
        }
        t += h.x;
    }
    return res;
}

vec3 render(in vec3 ro, in vec3 rd, float time) {
    // sky dome
    vec3 col = vec3(0.5, 0.8, 0.9) - max(rd.y, 0)*0.5;
    
    vec2 tm = castRay(ro, rd, time);

    if(tm.y > -0.5) {
        float t = tm.x;
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal(pos, time);
        vec3 ref = reflect(rd, nor);

        col = vec3(0.2);
        float ks = 1.0;

        if(tm.y ==1) {
            col = vec3(0.05, 0.09, 0.02);
            float f = -1+2*smoothstep(-0.2,0.2,sin(18*pos.x)+sin(18*pos.y)+sin(18*pos.z));
            col += 0.2*f*vec3(0.06,0.06,0.02);
        } else 
        if(tm.y ==2) { //body
            col = vec3(0.2, 0.05, 0.02);
        } else if (tm.y == 3) { //iris
            col = vec3(0.4, 0.4, 0.4);
        } else if (tm.y == 4) { //eyeball
            col = vec3(0.00);
        }

        vec3 sun_lig = normalize(vec3(0.6, 0.35, 0.5));
        float sun_dif = clamp(dot(nor, sun_lig), 0, 1); // diffuse
        vec3 sun_hal = normalize(sun_lig-rd);
        float sun_sha = step(castRay(pos+nor*0.001, sun_lig,time).y, 0);
        float sun_spe = ks * pow(clamp(dot(nor,sun_hal), 0,1),8)*sun_dif*(0.04+0.96*pow(clamp(1+dot(sun_hal,rd),0,1),5));
        float sky_dif = sqrt(clamp(0.5 + 0.5 * nor.y, 0, 1));
        float bou_dif = sqrt(clamp(0.1 - 0.9 * nor.y, 0, 1))*clamp(1-0.1*pos.y,0,1); // bounce light

        vec3 lin  = vec3(0.);
        lin += sun_dif *vec3(8.1, 6, 4.2)*sun_sha;
        lin += sky_dif *vec3(0.5,0.7,1);
        lin += bou_dif*vec3(0.4,1,0.4);
        col = col*lin;
        col += sun_spe*vec3(8.1,6,4.2)*sun_sha;
        col = mix(col,vec3(0.5,0.7,0.9), 1-exp(-0.0001*t*t*t));
    }

    return col;
}

mat3 setCamera(in vec3 ro, in vec3 ta, float cr) {
    vec3 cw = normalize(ta -ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = cross(cu, cw);
    return mat3(cu, cv, cw);
}

void main() {
    vec2 p = (2 * gl_FragCoord.xy - vec2(800,600)) / 600; // perspective

    float myTime = time * 0.9;

    // camera
    float an = 10.57*mouseX/resolutionX;myTime; //angle
    vec3 ta = vec3(0, .65, 0.4); //camera target
    vec3 ro = ta + vec3(1.3*cos(an), -0.250, 1.3*sin(an)); // camera origin

    mat3 ca = setCamera(ro, ta, 0);

    vec3 rd = ca * normalize(vec3(p,1.8)); // camera direction

    vec3 col = render(ro, rd, myTime);

    col = pow(col, vec3(0.4545)); // gamma correction

    FragColor = vec4(col, 1);
}

