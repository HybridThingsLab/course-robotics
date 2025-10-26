// Import libraries
import themidibus.*;
import oscP5.*;
import netP5.*;

// Canvas dimensions
int w = 800;
int h = 600;

// Position variables
float pos_x = w / 2;
float pos_z = h / 2;
float pos_y = 0.0;
float smooth = 0.1;

// Position limits
float pos_x_min = -0.5;
float pos_x_max = 0.5;
float pos_z_min = 0.0;
float pos_z_max = 1.0;
float pos_y_min = 0.6;
float pos_y_max = 0.9;

// Rotation variables
float rot_rx = -90;
float rot_ry = 0;
float rot_rz = 0;

// Rotation limits
float rot_x_min = -135;
float rot_x_max = -45;
float rot_y_min = -90;
float rot_y_max = 90;
float rot_z_min = -45;
float rot_z_max = 45;
float smooth_rotation = 0.1;

// MIDI variables
int[] MIDIchannels = {0, 1, 2, 3, 4, 5};
float[] controlValues = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5};

// MIDI and OSC objects
MidiBus myMidiBus;
OscP5 oscP5;
Boolean toggleSend = false;

void setup() {
  
  size(800, 600, P3D);
  
  // Load custom font
  //customFont = createFont("data/IBM_Plex_Mono/IBMPlexMono-Regular.ttf", 14);
  //textFont(customFont);
  
  // Initialize MIDI
  MidiBus.list(); // Lists all available MIDI devices in the console
  myMidiBus = new MidiBus(this, 2, 1); // Adjust MIDI input/output indices as needed
  
  // Initialize OSC
  oscP5 = new OscP5(this, 10000); // Listening on port 12000
  
  // Register OSC event handlers
  oscP5.plug(this, "iknosolution", "/iknosolution");
  oscP5.plug(this, "poseSafetyViolation", "/posesafetyviolation");
  oscP5.plug(this, "jointSafetyViolation", "/jointsafetyviolation");
  oscP5.plug(this, "moveJointsStart", "/movejointsstart");
  oscP5.plug(this, "moveJointsFinished", "/movejointsfinished");
  oscP5.plug(this, "stopped", "/stopped");
}

void draw() {
  background(0);

  // MIDI to position and rotation values
  float current_pos_x = controlValues[0];
  float current_pos_y = controlValues[1];
  float current_pos_z = 1.0 - controlValues[2];
  
  float current_rot_rx = map(controlValues[3], 0.0, 1.0, rot_x_min, rot_x_max);
  float current_rot_ry = map(controlValues[4], 0.0, 1.0, rot_y_min, rot_y_max);
  float current_rot_rz = map(controlValues[5], 0.0, 1.0, rot_z_min, rot_z_max);
  
  // Smooth the transitions
  pos_x = lerp(pos_x, current_pos_x, smooth);
  pos_y = lerp(pos_y, current_pos_y, smooth);
  pos_z = lerp(pos_z, current_pos_z, smooth);
  rot_rx = lerp(rot_rx, current_rot_rx, smooth_rotation);
  rot_ry = lerp(rot_ry, current_rot_ry, smooth_rotation);
  rot_rz = lerp(rot_rz, current_rot_rz, smooth_rotation);
  
  // Visualization
  pushMatrix();
  translate(pos_x * width, pos_z * height, pos_y * 500 - 500);
  rotateX(radians(rot_rx));
  rotateY(radians(rot_ry));
  rotateZ(radians(rot_rz));
  
  noStroke();
  fill(toggleSend ? color(255, 0, 255) : color(255));
  box(30);

  // Draw axes
  float axis_length = 80;
  float axis_width = 3;

  // Red X-axis
  fill(255, 0, 0);
  pushMatrix();
  translate(-axis_length / 2, 0, 0);
  box(axis_length, axis_width, axis_width);
  popMatrix();
  
  // Green Z-axis
  fill(0, 255, 0);
  pushMatrix();
  translate(0, 0, axis_length / 2);
  box(axis_width, axis_width, axis_length);
  popMatrix();

  // Blue Y-axis
  fill(0, 0, 255);
  pushMatrix();
  translate(0, -axis_length / 2, 0);
  box(axis_width, axis_length, axis_width);
  popMatrix();
  
  popMatrix();
  
  // Map and send OSC messages if toggle is active
  float mapped_x = map(pos_x, 1.0, 0.0, pos_x_min, pos_x_max);
  float mapped_y = map(pos_y, 0.0, 1.0, pos_y_min, pos_y_max);
  float mapped_z = map(pos_z, 1.0, 0.0, pos_z_min, pos_z_max);

  if (toggleSend) {
    OscMessage message = new OscMessage("/servopose");
    message.add(mapped_x);
    message.add(mapped_y);
    message.add(mapped_z);
    message.add(radians(rot_rx));
    message.add(radians(rot_ry));
    message.add(radians(rot_rz));
    message.add(1.0);
    oscP5.send(message, new NetAddress("127.0.0.1", 10001));
  }

  // Display text information
  displayText(mapped_x, mapped_y, mapped_z);
}


void displayText(float x, float y, float z) {
  fill(255);
  text("position: " + nf(x, 1, 3) + " " + nf(y, 1, 3) + " " + nf(z, 1, 3), -width/2 + 40, -height/2 + 40);
  text("rotation: " + nf(rot_rx, 1, 3) + "° " + nf(rot_ry, 1, 3) + "° " + nf(rot_rz, 1, 3) + "°", -width/2 + 40, -height/2 + 60);
  text("press SPACE to drive robot with servopose: " + toggleSend, -width/2 + 40, -height/2 + 80);
  text("press 's': stop robot", -width/2 + 40, -height/2 + 100);
  text("press 't': teach robot (= Freedrive)", -width/2 + 40, -height/2 + 120);
}

void keyPressed() {
  if (key == 's' || key == 'S') {
    OscMessage message = new OscMessage("/stop");
    message.add(0);
    oscP5.send(message, new NetAddress("127.0.0.1", 12000));
  }
  
  if (key == 't' || key == 'T') {
    OscMessage message = new OscMessage("/teachmode");
    message.add(0);
    oscP5.send(message, new NetAddress("127.0.0.1", 12000));
  }
  
  if (key == ' ') {
    toggleSend = !toggleSend;
  }
}

// OSC message handlers
void iknosolution(OscMessage msg) { println("/iknosolution"); }
void poseSafetyViolation(OscMessage msg) { println("/posesafetyviolation"); }
void jointSafetyViolation(OscMessage msg) { println("/jointsafetyviolation"); }
void moveJointsStart(OscMessage msg) { println("/movejointsstart"); }
void moveJointsFinished(OscMessage msg) { println("/movejointsfinished"); }
void stopped(OscMessage msg) { println("/stopped"); }

// MIDI message handler
void controllerChange(int channel, int number, int value) {
  for (int i = 0; i < MIDIchannels.length; i++) {
    if (number == MIDIchannels[i]) {
      controlValues[i] = value / 127.0;
    }
  }
}
