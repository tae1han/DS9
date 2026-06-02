// Shared bing constants (OSC paths still use /ds9/ prefix for wire compatibility).
8 => int NUM_AGENT_SLOTS;

// Role indices (station can assume any role via conductor)
0 => int ROLE_PARROT;
1 => int ROLE_PARAKEET;
2 => int ROLE_ALBATROSS;
3 => int ROLE_PEACOCK;
4 => int ROLE_EMU;
5 => int ROLE_FALCON;
6 => int ROLE_SWAN;
7 => int ROLE_OWL;

// Reserved MIDI (no monitor / phrase / pitchset). 28 = owl toggle; 29–35 = movements 2–8.
28 => int OWL_MIDI_TOGGLE;
29 => int MIDI_MOVEMENT_FIRST;
35 => int MIDI_MOVEMENT_LAST;

["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon", "Swan", "Owl"] @=> string ROLE_NAMES[];

// Local sim / default layout: slot i hosts role i (one bird per laptop).
fun int defaultRoleForSlot(int slot)
{
    return slot % NUM_AGENT_SLOTS;
}
