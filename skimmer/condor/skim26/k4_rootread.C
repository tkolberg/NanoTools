// Read every Events branch, entry by entry; report entries whose GetEntry fails.
#include <TFile.h>
#include <TTree.h>
#include <iostream>
void k4_rootread(const char* fn) {
  TFile* f = TFile::Open(fn); TTree* t = (TTree*)f->Get("Events");
  Long64_t n = t->GetEntries(), bad = 0, first = -1;
  for (Long64_t i = 0; i < n; ++i) if (t->GetEntry(i) <= 0) { if (first < 0) first = i; ++bad; }
  std::cout << "[rootread] " << gROOT->GetVersion() << " entries " << n << " bad " << bad << " first " << first << std::endl;
}
