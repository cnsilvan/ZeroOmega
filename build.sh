#!/bin/bash
cd omega-build
npm run deps
npm run dev
grunt
cd ../omega-target-chromium-extension
cd build
zip -r ../build.zip ./*
mv ../build.zip ~
cd ..
minify-all-js ./build -j
cd build && zip -r ../release.zip ./*
mv ../release.zip ~
