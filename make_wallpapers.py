#!/usr/bin/env python3
"""Crée deux fonds d'écran 1920x1080 (jour et nuit) dans le dossier donné. Usage: make_wallpapers.py theme/wallpapers
Tu peux les remplacer par tes propres images (mêmes noms: jour.jpg et nuit.jpg)."""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

W, H = 1920, 1080
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = x / W, y / H


def make(base, blobs, ribbons, strength):
    img = np.zeros((H, W, 3), np.float32)
    img[:] = np.array(base, np.float32)
    for cx, cy, rx, ry, col, k in blobs:
        d = ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2
        img += np.exp(-d)[..., None] * np.array(col, np.float32) * k
    for a, f, ph, col, wd, i in ribbons:
        cy = 0.35 + 0.18 * i + a * np.sin(u * f * np.pi * 2 / 1.6 + ph)
        img += np.exp(-((v - cy) / wd) ** 2)[..., None] * np.array(col, np.float32) * 0.14
    vg = 1 - 0.55 * (((u - .5) / .75) ** 2 + ((v - .5) / .8) ** 2)
    img *= np.clip(vg, 0.35, 1)[..., None] * strength
    img += np.random.default_rng(1).normal(0, 1.6, img.shape)  # évite les bandes de couleur
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))


RIB = [(0.10, 2.2, 0.0, (255, 255, 255), 0.020, 0), (0.13, 1.7, 1.6, (140, 200, 255), 0.030, 1),
       (0.08, 2.8, 3.1, (255, 170, 230), 0.025, 2)]
JOUR = [(.15, .20, .35, .45, (120, 60, 255), 1.0), (.80, .15, .30, .40, (0, 190, 255), .95),
        (.60, .80, .40, .35, (255, 60, 150), .95), (.10, .90, .30, .30, (255, 140, 40), .8),
        (.95, .75, .25, .35, (60, 90, 255), .8)]

out = sys.argv[1] if len(sys.argv) > 1 else "theme/wallpapers"
os.makedirs(out, exist_ok=True)
make((10, 12, 32), JOUR, RIB, 1.0).save(os.path.join(out, "jour.jpg"), quality=90)
make((4, 6, 16), JOUR, RIB, 0.45).save(os.path.join(out, "nuit.jpg"), quality=90)
print("fonds créés dans", out)
