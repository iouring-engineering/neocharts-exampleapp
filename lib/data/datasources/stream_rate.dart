/// Configures how frequently the mock data source pushes live ticks.
enum StreamRate { r1, r10, r30 }

extension StreamRateX on StreamRate {
  int get perSecond {
    switch (this) {
      case StreamRate.r1:
        return 1;
      case StreamRate.r10:
        return 10;
      case StreamRate.r30:
        return 30;
    }
  }

  Duration get interval {
    return const Duration(milliseconds: 500);
  }
}
