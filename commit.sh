#!/bin/bash
set -ex

git push
git add .
git commit -m `date +"%y/%m/%d"`
git push
