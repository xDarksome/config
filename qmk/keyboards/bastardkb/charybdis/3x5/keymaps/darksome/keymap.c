#include QMK_KEYBOARD_H

#include "quantum.h"

#define L1_TMB1 LGUI_T(KC_TAB)
#define L1_TMB2 LSFT_T(KC_SPC)
#define L1_TMB3 LT(NAV,KC_DEL)

#define R1_TMB1 RCTL_T(KC_BSPC)
#define R1_TMB2 LT(SYM,KC_ESC)

#define LG_SPC LGUI_T(KC_SPC)
#define LA_PGUP LALT_T(KC_PGUP)
#define LC_INS LCTL_T(KC_INS)
#define LS_PGDN LSFT_T(KC_PGDN)

#define RS_7 RSFT_T(KC_7)
#define RC_8 RCTL_T(KC_8)
#define RA_9 RALT_T(KC_9)
#define RG_ESC RGUI_T(KC_ESC)

#define R2_TMB1 LT(SYS, LCTL(KC_BSPC))
#define R2_TMB2 LT(SYM, KC_0)

#define G3_SPC LT(GAME3, KC_SPC)

enum custom_keycodes {
    G1_G = SAFE_RANGE,
    G1_DEL,
    G1_TAB,
};

enum layers {
  MAIN,
  MS,
  SCR,
  NAV,
  SYM,
  SYS,
  RU,
  GAME1,
  GAME2,
  GAME3,
};

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  // keymap for default
  [MAIN] = LAYOUT(
    KC_B    , KC_Y    , KC_O    , KC_U    , XXXXXXX ,                     XXXXXXX , KC_L    , KC_D    , KC_W    , KC_V    ,
    KC_C    , KC_I    , KC_E    , KC_A    , XXXXXXX ,                     XXXXXXX , KC_H    , KC_T    , KC_S    , KC_N    ,
    KC_G    , KC_X    , KC_J    , KC_K    , XXXXXXX ,                     XXXXXXX , KC_R    , KC_M    , KC_F    , KC_P    ,
                                  L1_TMB1 , L1_TMB2 , L1_TMB3 , R1_TMB1 , R1_TMB2
  ),

  [MS] = LAYOUT(
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ , KC_BTN1 , KC_BTN3 , KC_BTN2 , MO(SCR) ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
                                  _______ , _______ , _______ , _______ , TO(MAIN)
  ),

  [SCR] = LAYOUT(
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ , KC_BTN1 , KC_BTN3 , KC_BTN2 , TO(MAIN),
    KC_LGUI , KC_LALT , KC_LCTL , KC_LSFT , _______ ,                     _______ , TO(SCR) , _______ , _______ , _______ ,
                                  _______ , _______ , _______ , _______ , TO(MAIN)
  ),

  [NAV] = LAYOUT(
    KC_DEL  , KC_HOME , KC_UP   , KC_END  , _______ ,                     _______ , KC_1    , KC_2    , KC_3    , KC_BSPC ,
    KC_TAB  , KC_LEFT , KC_DOWN , KC_RGHT , _______ ,                     _______ , KC_4    , KC_5    , KC_6    , KC_ENT  ,
    LG_SPC  , LA_PGUP , LC_INS  , LS_PGDN , _______ ,                     _______ , RS_7    , RC_8    , RA_9    , RG_ESC  ,
                                  _______ , _______ , _______ , R2_TMB1 , R2_TMB2
  ),

  [SYM] = LAYOUT(
    KC_PIPE , KC_AMPR , KC_LCBR , KC_RCBR , _______ ,                     _______ , KC_LBRC , KC_RBRC , KC_GRV  , KC_EXLM ,
    KC_EQL  , KC_DQUO , KC_COLN , KC_SCLN , _______ ,                     _______ , KC_COMM , KC_DOT  , KC_QUOT , KC_QUES ,
    KC_MINS , KC_PLUS , KC_LT   , KC_GT   , _______ ,                     _______ , KC_LPRN , KC_RPRN , KC_ASTR , KC_SLSH ,
                                  KC_HASH , KC_UNDS , KC_AT   , _______ , _______
  ),

  [SYS] = LAYOUT(
   TO(GAME1),TO(GAME2), _______ , _______ , _______ ,                     _______ ,  KC_F1  ,  KC_F2  ,  KC_F3  , KC_F10  ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ ,  KC_F4  ,  KC_F5  ,  KC_F6  , KC_F11  ,
    KC_LGUI , KC_LALT , KC_LCTL , KC_LSFT , QK_BOOT ,                     _______ ,  KC_F7  ,  KC_F8  ,  KC_F9  , KC_F12  ,
                                  _______ , _______ , _______ , _______ , _______
  ),

  [RU] = LAYOUT(
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , _______ ,                     _______ , _______ , _______ , _______ , _______ ,
                                  _______ , _______ , _______ , _______ , _______
  ),

  [GAME1] = LAYOUT(
    _______ , _______ , _______ , _______ , KC_F1   ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , KC_F2   ,                     _______ , _______ , _______ , _______ , _______ ,
      G1_G  , _______ , _______ , _______ , KC_F3   ,                     _______ , _______ , _______ , _______ , _______ ,
                                  G1_TAB  , G3_SPC  , G1_DEL  , _______ , _______
  ),

  [GAME2] = LAYOUT(
    _______ , _______ , _______ , _______ , KC_F1  ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , KC_F2  ,                     _______ , _______ , _______ , _______ , _______ ,
    _______ , _______ , _______ , _______ , KC_F3  ,                     _______ , _______ , _______ , _______ , _______ ,
                                  KC_TAB  , KC_SPC  ,MO(GAME3), _______ , _______
  ),

  [GAME3] = LAYOUT(
    KC_V    , KC_W   , KC_D   , KC_L   , KC_F4   ,                     _______ , _______ , _______ , _______ , _______ ,
    KC_N    , KC_S   , KC_T   , KC_H   , KC_F5   ,                     _______ , _______ , _______ , _______ , _______ ,
    KC_P    , KC_F   , KC_M   , KC_R   , KC_F6   ,                     _______ , _______ , _______ , _______ , _______ ,
                                  _______ , _______ , _______ , TO(MAIN) , _______
  ),

  // [GAME3] = LAYOUT(
  //   KC_TAB  , KC_Q    , KC_W    , KC_E    , KC_R    ,                     _______ , _______ , _______ , _______ , _______ ,
  //   KC_LSFT , KC_A    , KC_S    , KC_D    , KC_F    ,                     _______ , _______ , _______ , _______ , _______ ,
  //   KC_LCTL , KC_Z    , KC_X    , KC_C    , KC_V    ,                     _______ , _______ , _______ , _______ , _______ ,
  //                                 KC_LALT , KC_SPC  ,MO(GAME4),_______ , _______
  // ),

  // [GAME4] = LAYOUT(
  //   KC_CAPS , KC_1    , KC_W    , KC_3    , KC_T    ,                     _______ , _______ , _______ , _______ , _______ ,
  //   KC_LSFT , KC_2    , KC_S    , KC_4    , KC_G    ,                     _______ , _______ , _______ , _______ , _______ ,
  //   KC_GRV  , KC_Z    , KC_X    , KC_5    , KC_B    ,                     _______ , _______ , _______ , _______ , _______ ,
  //                                 _______ , _______ , KC_ESC , TO(MAIN) , _______
  // ),
};
// clang-format on

layer_state_t layer_state_set_user(layer_state_t state) {
    // Enable scroll mode for SCR layer
    charybdis_set_pointer_dragscroll_enabled(get_highest_layer(state) == SCR);

    if (layer_state_is(SCR) && get_highest_layer(state) == MS) {
      return MAIN;
    };
   
    return state;
}

const uint16_t PROGMEM z[] = {KC_J, KC_K, COMBO_END};
const uint16_t PROGMEM q[] = {KC_R, KC_M, COMBO_END};

const uint16_t PROGMEM backslash[] = {KC_AMPR, KC_LCBR, COMBO_END};
const uint16_t PROGMEM percent[]   = {KC_LCBR, KC_RCBR, COMBO_END};
const uint16_t PROGMEM tilde[]     = {KC_DQUO, KC_COLN, COMBO_END};
const uint16_t PROGMEM dollar[]    = {KC_COLN, KC_SCLN, COMBO_END};
const uint16_t PROGMEM caret[]     = {KC_LT, KC_GT, COMBO_END};

enum combos {
  Z,
  Q,

  BACKSLASH,
  PERCENT,
  TILDE,
  DOLLAR,
  CARET,
};

combo_t key_combos[] = {
    [Z] = COMBO(z, KC_Z),
    [Q] = COMBO(q, KC_Q),

    [BACKSLASH] = COMBO(backslash, KC_BSLS),
    [PERCENT]   = COMBO(percent, KC_PERCENT), 
    [TILDE]     = COMBO(tilde, KC_TILD), 
    [DOLLAR]    = COMBO(dollar, KC_DLR),
    [CARET]     = COMBO(caret, KC_CIRC),
};

bool combo_should_trigger(uint16_t combo_index, combo_t *combo, uint16_t keycode, keyrecord_t *record) {
    switch (combo_index) {
        case Z: return layer_state_is(MAIN);
        case Q: return layer_state_is(MAIN);

        case BACKSLASH: return layer_state_is(SYM);
        case PERCENT:   return layer_state_is(SYM);
        case TILDE:     return layer_state_is(SYM);
        case DOLLAR:    return layer_state_is(SYM);
        case CARET:     return layer_state_is(SYM);
      }
    return false;
}

void keyboard_post_init_user(void) {
    set_auto_mouse_layer(MS);
    set_auto_mouse_enable(true);
}

bool handle_imm_mt(uint16_t keycode, keyrecord_t *record) {
    typedef struct {
        bool active;
        bool interrupted;
        uint16_t t0;
    } state_t;

    static state_t g1_g, g1_tab, g1_del;

    void mark_interrupt(state_t *st, uint16_t self_kc, uint16_t keycode, keyrecord_t *record) {
        if (!st->active) return;
        if (!record->event.pressed) return;
        if (keycode == self_kc) return;
        st->interrupted = true;
    }

    mark_interrupt(&g1_g, G1_G, keycode, record);
    mark_interrupt(&g1_tab, G1_TAB, keycode, record);
    mark_interrupt(&g1_del, G1_DEL, keycode, record);

    state_t* st;
    uint8_t mod_bit;
    uint16_t tap_kc;

    switch (keycode) {
      case G1_G:
        st = &g1_g;
        mod_bit = MOD_BIT(KC_LSFT);
        tap_kc = KC_G;
        break;
      case G1_TAB:
        st = &g1_tab;
        mod_bit = MOD_BIT(KC_LALT);
        tap_kc = KC_TAB;
        break;
      case G1_DEL:
        st = &g1_del;
        mod_bit = MOD_BIT(KC_LCTL);
        tap_kc = KC_DEL;
        break;
      default: return true; 
    }

    if (record->event.pressed) {
        st->active = true;
        st->interrupted = false;
        st->t0 = timer_read();

        register_mods(mod_bit);
    } else {
        unregister_mods(mod_bit);

        uint16_t elapsed = timer_elapsed(st->t0);
        bool is_tap = (elapsed < TAPPING_TERM);

        st->active = false;

        if (is_tap && !st->interrupted) {
            tap_code(tap_kc);
        }
    }

    return false;
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  // Makes mouse layer behave like "oneshot"
  if (!record->event.pressed && get_highest_layer(layer_state) == MS) {
    switch (keycode) {
      case KC_BTN1:
      case KC_BTN2:
      case KC_BTN3:
        layer_move(MAIN);
        break;
    }
  }

  return handle_imm_mt(keycode, record);
}
