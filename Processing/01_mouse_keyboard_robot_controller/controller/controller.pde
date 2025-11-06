// --- Libraries ---
import oscP5.*;
import netP5.*;

// --- Canvas ---
int w = 800;
int h = 600;

// --- Position (mouse-follow when pressed) ---
float pos_x = w / 2;
float pos_z = h / 2;
float pos_y = 0.0;
float smooth = 0.1;

// Distance control (w/s)
float distance_counter = 0.6;
float distance_counter_speed = 0.01;
float distance_min = 0.6;
float distance_max = 0.9;

// Rotation control
float rotation_min_rx = -135;
float rotation_max_rx = -45;
float rotation_min_ry = -90;
float rotation_max_ry = 90;
float rotation_min_rz = -45;
float rotation_max_rz = 45;
float rotation_counter_speed = 1;

float rot_rx_counter = -90;
float rot_rx = -90;
float rot_ry_counter = 0;
float rot_ry = 0;
float rot_rz_counter = 0;
float rot_rz = 0;
float smooth_rotation = 0.5;

// --- OSC ---
OscP5 oscP5;

// Optional: custom font
// PFont customFont;

void setup() {
  size(800, 600, P3D);

  // osc
  oscP5 = new OscP5(this, 10000);
  
  // register simple feedback handlers (like in p5.js)
  oscP5.plug(this, "iknosolution", "/iknosolution");
  oscP5.plug(this, "poseSafetyViolation", "/posesafetyviolation");
  oscP5.plug(this, "jointSafetyViolation", "/jointsafetyviolation");
  oscP5.plug(this, "moveJointsStart", "/movejointsstart");
  oscP5.plug(this, "moveJointsFinished", "/movejointsfinished");
  oscP5.plug(this, "stopped", "/stopped");

  // Optional font
  /*customFont = createFont("IBMPlexMono-14.vlw", 14);
  textFont(customFont);
  textSize(14);*/
}

void draw() {
  background(0);

  // follow mouse only while pressed (and allow key controls)
  if (mousePressed) {
    // DISTANCE: 'w' / 's'
    if (keyPressed) {
      if (key == 'w') distance_counter += distance_counter_speed;
      else if (key == 's') distance_counter -= distance_counter_speed;
      distance_counter = constrain(distance_counter, distance_min, distance_max);

      // ROT X: UP / DOWN
      if (keyCode == UP)   rot_rx_counter += rotation_counter_speed;
      if (keyCode == DOWN) rot_rx_counter -= rotation_counter_speed;
      rot_rx_counter = constrain(rot_rx_counter, rotation_min_rx, rotation_max_rx);

      // ROT Y: 'a' / 'd'
      if (key == 'a' || key == 'A') rot_ry_counter += rotation_counter_speed;
      if (key == 'd' || key == 'D') rot_ry_counter -= rotation_counter_speed;
      rot_ry_counter = constrain(rot_ry_counter, rotation_min_ry, rotation_max_ry);

      // ROT Z: LEFT / RIGHT
      if (keyCode == RIGHT) rot_rz_counter += rotation_counter_speed;
      if (keyCode == LEFT)  rot_rz_counter -= rotation_counter_speed;
      rot_rz_counter = constrain(rot_rz_counter, rotation_min_rz, rotation_max_rz);
    }

    // smooth toward mouse and counters
    pos_x = lerp(pos_x, mouseX, smooth);
    pos_z = lerp(pos_z, mouseY, smooth);
    pos_y = lerp(pos_y, distance_counter, smooth);
    rot_rx = lerp(rot_rx, rot_rx_counter, smooth_rotation);
    rot_ry = lerp(rot_ry, rot_ry_counter, smooth_rotation);
    rot_rz = lerp(rot_rz, rot_rz_counter, smooth_rotation);

    // clamp to canvas
    pos_x = constrain(pos_x, 0, width);
    pos_z = constrain(pos_z, 0, height);
  }

  // --- Visualization (match look/feel of p5.js) ---
  stroke(mousePressed ? color(255, 0, 255) : color(255));
  noFill();
  strokeWeight(2);

  pushMatrix();
  // In p5.js WEBGL they map distance to Z (10..300)
  float z_position = map(pos_y, distance_min, distance_max, 10, 300);

  // Processing origin is top-left; just translate to (pos_x, pos_z)
  translate(pos_x, pos_z, z_position);
  rotateX(radians(rot_rx));
  rotateY(radians(rot_ry));
  rotateZ(radians(rot_rz));
  box(50);

  // axes (x=red, z=green, y=blue)
  float axis_length = 80;
  float axis_width = 3;

  noStroke();

  // X (red)
  fill(255, 0, 0);
  pushMatrix();
  translate(-axis_length/2.0, 0, 0);
  box(axis_length, axis_width, axis_width);
  popMatrix();

  // Z (green)
  fill(0, 255, 0);
  pushMatrix();
  translate(0, 0, axis_length/2.0);
  box(axis_width, axis_width, axis_length);
  popMatrix();

  // Y (blue)
  fill(0, 0, 255);
  pushMatrix();
  translate(0, -axis_length/2.0, 0);
  box(axis_width, axis_length, axis_width);
  popMatrix();

  popMatrix();

  // --- OSC send (only while mouse pressed, as in p5.js) ---
  float mapped_x = map(pos_x, 0, width, -0.5, 0.5);
  float mapped_z = map(pos_z, 0, height, 1.0, 0.0);

  if (mousePressed) {
    OscMessage message = new OscMessage("/servopose");
    message.add(mapped_x);
    message.add(pos_y);
    message.add(mapped_z);
    message.add(radians(rot_rx));
    message.add(radians(rot_ry));
    message.add(radians(rot_rz));
    message.add(1.0); // trailing flag, same as p5.js
    oscP5.send(message, new NetAddress("127.0.0.1", 10001));
  }

  // --- UI text (screen space, top-left) ---
  fill(255);
  noStroke();
  text("position: " + nf(mapped_x, 1, 3) + " " + nf(pos_y, 1, 3) + " " + nf(mapped_z, 1, 3), 40, 40);
  text("rotation: " + nf(rot_rx, 1, 3) + "° " + nf(rot_ry, 1, 3) + "° " + nf(rot_rz, 1, 3) + "°", 40, 60);
  text("press 'w' and 's': pos_y", 40, 80);
  text("press ↑/↓: rot_x | →/←: rot_z | 'a'/'d': rot_y", 40, 100);
  text("press 's': stop robot", 40, 120);
  text("press 't': teach robot (= Freedrive)", 40, 140);
}

// --- Key commands (like p5.js) ---
void keyPressed() {
  // 's' -> /stop
  if (key == 's' || key == 'S') {
    OscMessage m = new OscMessage("/stop");
    m.add(0);
    oscP5.send(m, new NetAddress("127.0.0.1", 12000));
  }

  // 't' -> /teachmode
  if (key == 't' || key == 'T') {
    OscMessage m = new OscMessage("/teachmode");
    m.add(0);
    oscP5.send(m, new NetAddress("127.0.0.1", 12000));
  }
}

// --- OSC feedback handlers (console logs) ---
void iknosolution(OscMessage msg){ println("/iknosolution"); }
void poseSafetyViolation(OscMessage msg){ println("/posesafetyviolation"); }
void jointSafetyViolation(OscMessage msg){ println("/jointsafetyviolation"); }
void moveJointsStart(OscMessage msg){ println("/movejointsstart"); }
void moveJointsFinished(OscMessage msg){ println("/movejointsfinished"); }
void stopped(OscMessage msg){ println("/stopped"); }
