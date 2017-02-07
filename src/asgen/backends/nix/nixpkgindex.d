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

module asgen.backends.nix.nixpkgindex;

import std.stdio;
import std.path;
import std.string;
import std.algorithm : canFind;
import std.array : appender;
static import std.file;

import asgen.logging;
import asgen.zarchive;
import asgen.backends.interfaces;
import asgen.backends.nix.nixpkg;

class NixPackageIndex : PackageIndex
{

private:
  string rootDir;
  Package[][string] pkgCache;
  Path nixpkgsPath;
  string binaryCacheUri;

  public:

  this (string dir)
  {
    this.rootDir = dir;
    if (!std.file.exists (dir))
      throw new Exception ("Directory '%s' does not exist.", dir);

    nixpkgsPath = "/nix/var/nix/profiles/per-user/root/channels/nixpkgs/";
    binaryCacheUri = "http://nix-cache.s3.amazonaws.com/";

    initNix();
    initGC();
    settings.readOnlyMode = true;
    settings.showTrace = true;

    auto localStore = openStore();
    auto binaryCache = openStore(binaryCacheUri);

    /* Get the allowed store paths to be included in the database. */
    auto allowedPaths = tokenizeString<PathSet>(readFile(storePathsFile, true));
    PathSet allowedPathsClosure;
    binaryCache->computeFSClosure(allowedPaths, allowedPathsClosure);

    EvalState state({}, localStore);

    Value vRoot;
    state.eval(state.parseExprFromFile(resolveExprPath(nixpkgsPath)), vRoot);
  }

  void release ()
  {
    pkgCache = null;
  }

  private Package[] loadPackages (string suite, string section, string arch)
  {
    /* Get all derivations. */
    DrvInfos packages;

    auto args = state.allocBindings(2);
    Value * vConfig = state.allocValue();
    state.mkAttrs(*vConfig, 0);
    args->push_back(Attr(state.symbols.create("config"), vConfig));
    Value * vSystem = state.allocValue();
    mkString(*vSystem, arch);
    args->push_back(Attr(state.symbols.create("system"), vSystem));
    args->sort();
    getDerivations(state, vRoot, "", *args, packages, true);

    NixPackage[string] pkgs;
    for (auto & p : packages) {
      auto pkg = new NixPackage (p, binaryCacheUri);
      pkgs[pkg.name] = pkg;
    }

    return pkgs.values;
  }

  Package[] packagesFor (string suite, string section, string arch)
  {
    immutable id = "%s-%s-%s".format (suite, section, arch);
    if (id !in pkgCache) {
      auto pkgs = loadPackages (suite, section, arch);
      synchronized (this) pkgCache[id] = pkgs;
    }

    return pkgCache[id];
  }

  // TODO: check based on most recent evaluation/nixpkgs hash
  bool hasChanges (DataStore dstore, string suite, string section, string arch)
  {
    return true;
  }
}
