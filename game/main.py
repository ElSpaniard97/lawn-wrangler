"""
Lawn Wrangler - a small landscaping game made with pygame.

Ride the lawn mower to cut big open areas fast, then hop off and use the
weed eater to trim the edges the mower can't reach (around the house,
trees, flower beds and fence).

Controls
  Arrow keys / WASD  move
  SPACE              hop off the mower, or hop back on when you're next to it
  R                  restart
"""

import asyncio
import math
import random

import pygame

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
WIDTH, HEIGHT = 960, 640
HUD_HEIGHT = 48
TILE = 12  # size of one grass patch in pixels
COLS = WIDTH // TILE
ROWS = (HEIGHT - HUD_HEIGHT) // TILE
FPS = 60
GOAL_PERCENT = 99  # how much of the lawn must be cut to win

# Colors
TALL_GRASS = (46, 110, 40)
TALL_GRASS_SPECK = (36, 92, 32)
STRIPE_LIGHT = (126, 196, 92)
STRIPE_DARK = (98, 170, 70)
HOUSE_WALL = (200, 180, 150)
HOUSE_ROOF = (150, 70, 60)
FLOWER_BED = (110, 80, 50)
TREE_TRUNK = (100, 70, 40)
TREE_LEAVES = (40, 90, 45)
FENCE = (230, 230, 220)
HUD_BG = (35, 35, 40)
WHITE = (245, 245, 245)
YELLOW = (250, 215, 80)

# Grass states
TALL = 0
CUT_LIGHT = 1
CUT_DARK = 2
BLOCKED = 3  # something sits on this tile, so there's no grass to cut


# ---------------------------------------------------------------------------
# The yard: obstacles and the grid of grass tiles
# ---------------------------------------------------------------------------
class Yard:
    def __init__(self):
        top = HUD_HEIGHT
        # Everything the player can bump into. Each one is a pygame.Rect.
        self.fence_thickness = 8
        self.house = pygame.Rect(360, top + 8, 240, 130)
        self.flower_beds = [
            pygame.Rect(120, top + 330, 140, 50),
            pygame.Rect(700, top + 380, 60, 140),
        ]
        self.trees = [  # (center x, center y, radius)
            (220, top + 170, 30),
            (780, top + 200, 34),
            (480, top + 420, 28),
        ]
        self.obstacles = [self.house] + self.flower_beds
        for x, y, r in self.trees:
            self.obstacles.append(pygame.Rect(x - r, y - r, r * 2, r * 2))
        t = self.fence_thickness
        self.obstacles += [
            pygame.Rect(0, top, WIDTH, t),  # top fence
            pygame.Rect(0, HEIGHT - t, WIDTH, t),  # bottom fence
            pygame.Rect(0, top, t, HEIGHT - top),  # left fence
            pygame.Rect(WIDTH - t, top, t, HEIGHT - top),  # right fence
        ]

        # The grass grid. grid[row][col] holds TALL, CUT_LIGHT, CUT_DARK or BLOCKED.
        self.grid = [[TALL] * COLS for _ in range(ROWS)]
        for row in range(ROWS):
            for col in range(COLS):
                if any(o.colliderect(self.tile_rect(col, row)) for o in self.obstacles):
                    self.grid[row][col] = BLOCKED
        self.total_grass = sum(row.count(TALL) for row in self.grid)
        self.cut_count = 0

        # We draw the lawn onto its own surface and only repaint tiles that
        # change. That keeps the game fast, even in a web browser.
        self.lawn = pygame.Surface((WIDTH, HEIGHT - HUD_HEIGHT))
        for row in range(ROWS):
            for col in range(COLS):
                self.paint_tile(col, row)

    @staticmethod
    def tile_rect(col, row):
        return pygame.Rect(col * TILE, HUD_HEIGHT + row * TILE, TILE, TILE)

    def paint_tile(self, col, row):
        x, y = col * TILE, row * TILE
        state = self.grid[row][col]
        if state == TALL:
            self.lawn.fill(TALL_GRASS, (x, y, TILE, TILE))
            # A few darker blades so tall grass looks shaggy.
            rnd = random.Random(row * 1000 + col)  # same pattern every time
            for _ in range(3):
                bx = x + rnd.randrange(TILE)
                by = y + rnd.randrange(TILE - 4)
                pygame.draw.line(self.lawn, TALL_GRASS_SPECK, (bx, by), (bx, by + 4))
        elif state == CUT_LIGHT:
            self.lawn.fill(STRIPE_LIGHT, (x, y, TILE, TILE))
        elif state == CUT_DARK:
            self.lawn.fill(STRIPE_DARK, (x, y, TILE, TILE))
        else:
            self.lawn.fill(TALL_GRASS, (x, y, TILE, TILE))

    def cut(self, cx, cy, radius, stripe):
        """Cut every tall tile within `radius` pixels of (cx, cy).
        Returns how many tiles were cut this time."""
        cut_now = 0
        col_min = max(0, int((cx - radius) // TILE))
        col_max = min(COLS - 1, int((cx + radius) // TILE))
        row_min = max(0, int((cy - radius - HUD_HEIGHT) // TILE))
        row_max = min(ROWS - 1, int((cy + radius - HUD_HEIGHT) // TILE))
        for row in range(row_min, row_max + 1):
            for col in range(col_min, col_max + 1):
                if self.grid[row][col] != TALL:
                    continue
                tx = col * TILE + TILE / 2
                ty = HUD_HEIGHT + row * TILE + TILE / 2
                if math.hypot(tx - cx, ty - cy) <= radius:
                    self.grid[row][col] = stripe
                    self.paint_tile(col, row)
                    cut_now += 1
        self.cut_count += cut_now
        return cut_now

    def percent_cut(self):
        return 100 * self.cut_count / self.total_grass

    def blocked(self, rect):
        return rect.collidelist(self.obstacles) != -1

    def draw(self, screen):
        screen.blit(self.lawn, (0, HUD_HEIGHT))
        for bed in self.flower_beds:
            pygame.draw.rect(screen, FLOWER_BED, bed, border_radius=6)
            rnd = random.Random(bed.x)
            for _ in range(bed.w * bed.h // 250):
                fx = rnd.randrange(bed.left + 6, bed.right - 6)
                fy = rnd.randrange(bed.top + 6, bed.bottom - 6)
                color = rnd.choice([(230, 70, 90), (250, 200, 60), (180, 110, 230)])
                pygame.draw.circle(screen, color, (fx, fy), 4)
        h = self.house
        pygame.draw.rect(screen, HOUSE_WALL, h)
        pygame.draw.rect(screen, HOUSE_ROOF, h.inflate(-20, -20))
        pygame.draw.line(screen, (120, 55, 50), h.inflate(-20, -20).midleft, h.inflate(-20, -20).midright, 3)
        for x, y, r in self.trees:
            pygame.draw.circle(screen, (30, 70, 35), (x + 4, y + 6), r)  # shadow
            pygame.draw.circle(screen, TREE_LEAVES, (x, y), r)
            pygame.draw.circle(screen, (55, 115, 60), (x - r // 3, y - r // 3), r // 2)
        for fence in self.obstacles[-4:]:
            pygame.draw.rect(screen, FENCE, fence)


# ---------------------------------------------------------------------------
# The player and the mower
# ---------------------------------------------------------------------------
class Mower:
    """The riding mower. Big body, wide blade, fast, can't fit near edges."""

    SIZE = 52
    SPEED = 190  # pixels per second
    CUT_RADIUS = 15  # the blade sits under the body, so it can't reach right up to edges

    def __init__(self, x, y):
        self.x, self.y = x, y
        self.angle = 0  # degrees, 0 = facing right

    def rect(self, x=None, y=None):
        x = self.x if x is None else x
        y = self.y if y is None else y
        return pygame.Rect(x - self.SIZE / 2, y - self.SIZE / 2, self.SIZE, self.SIZE)

    def draw(self, screen, driver_on):
        body = pygame.Surface((self.SIZE + 8, self.SIZE), pygame.SRCALPHA)
        pygame.draw.rect(body, (200, 40, 40), (4, 6, self.SIZE, self.SIZE - 12), border_radius=8)  # red body
        pygame.draw.rect(body, (60, 60, 60), (8, 0, 12, 8), border_radius=2)  # wheels
        pygame.draw.rect(body, (60, 60, 60), (8, self.SIZE - 8, 12, 8), border_radius=2)
        pygame.draw.rect(body, (60, 60, 60), (self.SIZE - 12, 2, 10, 6), border_radius=2)
        pygame.draw.rect(body, (60, 60, 60), (self.SIZE - 12, self.SIZE - 8, 10, 6), border_radius=2)
        pygame.draw.rect(body, (40, 40, 40), (12, 12, 14, self.SIZE - 24), border_radius=4)  # seat
        if driver_on:
            pygame.draw.circle(body, (240, 200, 160), (20, self.SIZE // 2), 7)  # driver's head
            pygame.draw.circle(body, YELLOW, (19, self.SIZE // 2), 7, 3)  # cap
        turned = pygame.transform.rotate(body, -self.angle)
        screen.blit(turned, turned.get_rect(center=(self.x, self.y)))


class Walker:
    """The person on foot with a weed eater. Small, slow, reaches tight edges."""

    SIZE = 14
    SPEED = 120
    CUT_RADIUS = 13

    def __init__(self, x, y):
        self.x, self.y = x, y
        self.angle = 0
        self.spin = 0  # weed eater line spin, just for looks

    def rect(self, x=None, y=None):
        x = self.x if x is None else x
        y = self.y if y is None else y
        return pygame.Rect(x - self.SIZE / 2, y - self.SIZE / 2, self.SIZE, self.SIZE)

    def tool_tip(self):
        """Where the spinning string of the weed eater is."""
        rad = math.radians(self.angle)
        return self.x + math.cos(rad) * 14, self.y + math.sin(rad) * 14

    def draw(self, screen):
        tx, ty = self.tool_tip()
        pygame.draw.line(screen, (90, 90, 90), (self.x, self.y), (tx, ty), 3)
        for i in range(3):  # spinning line
            a = self.spin + i * 2.09
            pygame.draw.line(screen, WHITE, (tx, ty), (tx + math.cos(a) * 8, ty + math.sin(a) * 8), 1)
        pygame.draw.circle(screen, (40, 90, 200), (int(self.x), int(self.y)), 8)  # blue shirt
        pygame.draw.circle(screen, (240, 200, 160), (int(self.x), int(self.y)), 5)  # head
        pygame.draw.circle(screen, YELLOW, (int(self.x), int(self.y)), 5, 2)  # cap


class Clipping:
    """A little flying piece of grass, for juice."""

    def __init__(self, x, y):
        self.x, self.y = x, y
        a = random.uniform(0, math.tau)
        speed = random.uniform(30, 90)
        self.vx, self.vy = math.cos(a) * speed, math.sin(a) * speed
        self.life = random.uniform(0.3, 0.6)

    def update(self, dt):
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.life -= dt

    def draw(self, screen):
        pygame.draw.rect(screen, STRIPE_LIGHT, (self.x, self.y, 3, 2))


# ---------------------------------------------------------------------------
# The game itself
# ---------------------------------------------------------------------------
class Game:
    def __init__(self):
        self.font = pygame.font.Font(None, 30)
        self.big_font = pygame.font.Font(None, 72)
        self.reset()

    def reset(self):
        self.yard = Yard()
        self.mower = Mower(120, HUD_HEIGHT + 80)
        self.walker = Walker(self.mower.x, self.mower.y)
        self.on_mower = True
        self.clippings = []
        self.time = 0.0
        self.won = False
        self.message = "Mow the big areas, then hop off (SPACE) to trim the edges!"
        self.message_timer = 5.0

    def handle_key(self, key):
        if key == pygame.K_r:
            self.reset()
        elif key == pygame.K_SPACE and not self.won:
            self.toggle_mower()

    def toggle_mower(self):
        if self.on_mower:
            # Step off beside the mower, wherever there's room.
            for dx, dy in [(0, 34), (0, -34), (34, 0), (-34, 0)]:
                x, y = self.mower.x + dx, self.mower.y + dy
                if not self.yard.blocked(self.walker.rect(x, y)):
                    self.walker.x, self.walker.y = x, y
                    self.on_mower = False
                    self.say("Weed eater out! Trim along the edges.")
                    return
            self.say("No room to step off here.")
        else:
            close = math.hypot(self.walker.x - self.mower.x, self.walker.y - self.mower.y) < 50
            if close:
                self.on_mower = True
                self.say("Back on the mower.")
            else:
                self.say("Walk over to the mower to hop back on.")

    def say(self, text):
        self.message = text
        self.message_timer = 2.5

    def update(self, dt):
        self.message_timer -= dt
        for c in self.clippings:
            c.update(dt)
        self.clippings = [c for c in self.clippings if c.life > 0]
        if self.won:
            return
        self.time += dt

        keys = pygame.key.get_pressed()
        dx = (keys[pygame.K_RIGHT] or keys[pygame.K_d]) - (keys[pygame.K_LEFT] or keys[pygame.K_a])
        dy = (keys[pygame.K_DOWN] or keys[pygame.K_s]) - (keys[pygame.K_UP] or keys[pygame.K_w])
        mover = self.mower if self.on_mower else self.walker
        if not self.on_mower:
            self.walker.spin += dt * 30

        if dx or dy:
            length = math.hypot(dx, dy)
            step = mover.SPEED * dt
            # Move one axis at a time so you can slide along walls.
            new_x = mover.x + dx / length * step
            if not self.yard.blocked(mover.rect(new_x, mover.y)):
                mover.x = new_x
            new_y = mover.y + dy / length * step
            if not self.yard.blocked(mover.rect(mover.x, new_y)):
                mover.y = new_y
            mover.angle = math.degrees(math.atan2(dy, dx))

            # Cut grass. Moving sideways makes light stripes and moving up or
            # down makes dark ones, just like a real lawn.
            stripe = CUT_LIGHT if abs(dx) >= abs(dy) else CUT_DARK
            if self.on_mower:
                cx, cy, radius = mover.x, mover.y, Mower.CUT_RADIUS
            else:
                cx, cy = self.walker.tool_tip()
                radius = Walker.CUT_RADIUS
            if self.yard.cut(cx, cy, radius, stripe):
                for _ in range(3):
                    self.clippings.append(Clipping(cx, cy))

        if self.yard.percent_cut() >= GOAL_PERCENT:
            self.won = True

    def draw(self, screen):
        self.yard.draw(screen)
        self.mower.draw(screen, driver_on=self.on_mower)
        if not self.on_mower:
            self.walker.draw(screen)
        for c in self.clippings:
            c.draw(screen)
        self.draw_hud(screen)
        if self.won:
            self.draw_win(screen)

    def draw_hud(self, screen):
        pygame.draw.rect(screen, HUD_BG, (0, 0, WIDTH, HUD_HEIGHT))
        pct = self.yard.percent_cut()
        bar = pygame.Rect(16, 14, 240, 20)
        pygame.draw.rect(screen, (70, 70, 80), bar, border_radius=6)
        fill = bar.copy()
        fill.w = int(bar.w * min(pct / GOAL_PERCENT, 1))
        pygame.draw.rect(screen, STRIPE_LIGHT, fill, border_radius=6)
        screen.blit(self.font.render(f"{pct:4.1f}% cut", True, WHITE), (268, 14))
        tool = "Riding mower" if self.on_mower else "Weed eater"
        screen.blit(self.font.render(tool, True, YELLOW), (420, 14))
        t = self.font.render(f"Time {int(self.time) // 60}:{int(self.time) % 60:02d}", True, WHITE)
        screen.blit(t, (WIDTH - t.get_width() - 16, 14))
        if self.message_timer > 0 and not self.won:
            msg = self.font.render(self.message, True, WHITE)
            box = msg.get_rect(midbottom=(WIDTH // 2, HEIGHT - 16)).inflate(20, 10)
            pygame.draw.rect(screen, HUD_BG, box, border_radius=8)
            screen.blit(msg, msg.get_rect(center=box.center))

    def draw_win(self, screen):
        shade = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        shade.fill((0, 0, 0, 140))
        screen.blit(shade, (0, 0))
        title = self.big_font.render("Yard complete!", True, YELLOW)
        screen.blit(title, title.get_rect(center=(WIDTH // 2, HEIGHT // 2 - 30)))
        info = self.font.render(
            f"Finished in {int(self.time) // 60}:{int(self.time) % 60:02d}. Press R to mow again.", True, WHITE
        )
        screen.blit(info, info.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 30)))


# ---------------------------------------------------------------------------
# Main loop. It's "async" so pygbag can run it in a web browser.
# ---------------------------------------------------------------------------
async def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Lawn Wrangler")
    clock = pygame.time.Clock()
    game = Game()

    running = True
    while running:
        dt = min(clock.tick(FPS) / 1000, 0.05)  # seconds since last frame
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                game.handle_key(event.key)
        game.update(dt)
        game.draw(screen)
        pygame.display.flip()
        await asyncio.sleep(0)  # lets the browser breathe between frames

    pygame.quit()


if __name__ == "__main__":
    asyncio.run(main())
