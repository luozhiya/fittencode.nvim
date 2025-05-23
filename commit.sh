#!/bin/bash
set -ex

git push
git add .
git commit -m `date +"%Y/%m/%d"`
git push
