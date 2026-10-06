import os
os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['SDL_AUDIODRIVER'] = 'dummy'
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import pygame
from game.main import Game, Yard, WIDTH, HEIGHT, HUD_HEIGHT, TALL, CUT_LIGHT

class GameTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()
        pygame.display.set_mode((WIDTH, HEIGHT))

    def game(self):
        with patch.object(Game, 'load_best', return_value=None):
            return Game()

    def test_pause_freezes_time_and_position(self):
        g = self.game()
        g.handle_key(pygame.K_p)
        g.update(3)
        self.assertEqual(g.time, 0)
        g.handle_key(pygame.K_SPACE)
        self.assertTrue(g.on_mower)
        g.handle_key(pygame.K_p)
        g.update(.2)
        self.assertAlmostEqual(g.time, .2)

    def test_tree_corners_and_trunk(self):
        y = Yard()
        self.assertFalse(y.blocked(pygame.Rect(190, HUD_HEIGHT + 140, 3, 3)))
        self.assertTrue(y.blocked(pygame.Rect(215, HUD_HEIGHT + 165, 10, 10)))
        self.assertTrue(y.blocked(pygame.Rect(-20, 250, 10, 10)))

    def test_parked_mower_and_dismount(self):
        g = self.game()
        g.toggle_mower()
        self.assertFalse(g.on_mower)
        self.assertFalse(g.movement_blocked(g.walker.rect()))
        self.assertTrue(g.movement_blocked(g.mower.rect()))
        g.toggle_mower()
        self.assertTrue(g.on_mower)

    def test_cutting_idempotent_and_record_updates_once(self):
        g = self.game()
        first = g.yard.cut(120, 250, 20, CUT_LIGHT)
        self.assertGreater(first, 0)
        self.assertEqual(g.yard.cut(120, 250, 20, CUT_LIGHT), 0)
        g.yard.cut_count = g.yard.total_grass
        with patch.object(g, 'save_best') as save:
            g.update(.2)
            g.update(.2)
            self.assertTrue(g.won)
            self.assertEqual(g.best_time, .2)
            save.assert_called_once()

    def test_saved_record_survives_reload_and_rejects_invalid_data(self):
        g = self.game()
        with tempfile.TemporaryDirectory() as folder, patch('game.main.Path.home', return_value=Path(folder)):
            g.best_time = 83.25
            g.save_best()
            self.assertEqual(Game.load_best(), 83.25)
            for value in ['null', '"bad"', '-5', 'NaN']:
                (Path(folder) / '.lawn-wrangler-best.json').write_text(value)
                self.assertIsNone(Game.load_best())

    def test_render_states(self):
        g = self.game()
        screen = pygame.display.get_surface()
        for paused, highlight in [(False, False), (True, True)]:
            g.paused, g.highlight = paused, highlight
            g.draw(screen)
        g.paused = False
        g.yard.cut_count = g.yard.total_grass
        with patch.object(g, 'save_best'):
            g.update(.1)
        g.draw(screen)

if __name__ == '__main__':
    unittest.main()
