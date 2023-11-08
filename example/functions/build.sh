#!/bin/bash
BUILDDIR=.build
OUTDIR=out

if [ -d "$BUILDDIR" ]; then
    echo "Build directory exists"
    rm -rf $BUILDDIR
fi
cp -r src $BUILDDIR
cd $BUILDDIR

npm install --omit-dev
npx tsc -p tsconfig.json --outDir "$OUTDIR"

for f in $OUTDIR/*; do
    echo "Zipping $f"
    zip -r $f.zip $f
done;

mkdir $OUTDIR/nodejs
mv node_modules $OUTDIR/nodejs
zip -r $OUTDIR/node_package.zip $OUTDIR/nodejs