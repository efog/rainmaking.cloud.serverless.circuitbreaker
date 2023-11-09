#!/bin/bash
BUILDDIR=.build
OUTDIR=out

if [ -d "$BUILDDIR" ]; then
    echo "Build directory exists"
    rm -rf $BUILDDIR
fi

mkdir $BUILDDIR
rsync -av --exclude='src/node_modules' src $BUILDDIR

cd $BUILDDIR/src

npm install --omit-dev
npx tsc -p tsconfig.json --outDir out

for f in $OUTDIR/*; do
    echo "Zipping $f"
    zip -r $f.zip $f
done;

mkdir $OUTDIR/nodejs
mv node_modules $OUTDIR/nodejs
zip -r $OUTDIR/node_package.zip $OUTDIR/nodejs