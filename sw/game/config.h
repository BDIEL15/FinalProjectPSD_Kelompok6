#ifndef CONFIG_H
#define CONFIG_H

#include "game.h"

/* Baca sw/config.ini ke params. Return 0 = OK, -1 = file tidak bisa dibuka,
 * -2 = ada key wajib yang tidak ditemukan (namanya dicetak ke stderr). */
int config_load(const char *path, game_params_t *params);

#endif
