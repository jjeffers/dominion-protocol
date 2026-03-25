#!/bin/bash

# Generates a PDF of the player manual using md-to-pdf locally
echo "Generating Player Manual PDF..."
npx md-to-pdf docs/player_manual.md --config-file .md-to-pdf.js
echo "Successfully generated docs/player_manual.pdf!"
