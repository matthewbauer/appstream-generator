/*
 * Copyright (C) 2017 Matthew Bauer <mjbauer95@gmail.com>
 *
 * Licensed under the GNU Lesser General Public License Version 3
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the license, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this software.  If not, see <http://www.gnu.org/licenses/>.
 */

module asgen.backends.nix.nixpkg;

import std.stdio;
import std.string;
import std.array : empty;

import asgen.logging;
import asgen.zarchive;
import asgen.backends.interfaces;

import asgen.utils : downloadFile;

class NixPackage : Package
{
private:
  DrvInfo drv;

  string tmpDir;
  string binaryCacheUri;

  ArchiveDecompressor archive;

public:

  this (DrvInfo val, string binaryCacheUri)
  {
    val = val;
    tmpDir = buildPath (conf.getTmpDir (), format ("%s_%s", drv.name, drv.system));
    binaryCacheUri = binaryCacheUri;
  }

  ~this ()
  {
  }

  override
  @property string name () const { return DrvName(drv.name).name; }

  override
  @property void ver (string val) { return DrvName(drv.name).version; }

  override
  @property string arch () const { return drv.system; }

  override
  @property string maintainer () const {
    const Value * maintainers = drv.queryMeta("maintainers");
    if (!maintainers) return "";
    if (!maintainers->isList()) return "";
    if (maintainers->listSize() == 0) return "";
    const Value * maintainer = maintainers[0];
    if (maintainer->type != tString) return "";
    return maintainer->string.s;
  }

  override
  @property string filename () const {
    hash = storePathToHash (drv.queryOutPath());
    return buildNormalizedPath (tmpDir, hash + ".nar.xz");
  }

  override
  @property const(string[string]) description () const {
    string[string] desc;
    desc["C"] = drv.queryMetaString ("description");
    return desc;
  }

  override
  const(ubyte)[] getFileData (string fname)
  {
    if (!archive.isOpen ()) {
      hash = storePathToHash (drv.queryOutPath());
      url = binaryCacheUri + "/" + hash + ".nar.xz";
      immutable path = buildNormalizedPath (tmpDir, hash + ".nar.xz");

      synchronized (this) {
        downloadFile (url, this.filename);
      }

      archive.open (this.filename);
    }

    return archive.readData (fname);
  }

  @property override
  string[] contents ()
  {
    hash = storePathToHash (drv.outPath);
    url = binaryCacheUri + "/" + hash + ".ls.xz";
    immutable path = buildNormalizedPath (tmpDir, hash + ".ls.xz");

    synchronized (this) {
      downloadFile (url, path);
    }

    data = decompressData (path);
    return splitLines (data);
  }

  override
  void close ()
  {
  }
}
