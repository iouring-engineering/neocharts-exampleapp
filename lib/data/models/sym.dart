import 'package:equatable/equatable.dart';

class Sym extends Equatable {
  final String id;
  final String spotID;
  final String dispName;
  final String instrument;
  final String streamSym;
  final String baseSym;
  final String exchange;
  final String excToken;
  final String series;
  final String lot;
  final String tick;
  final String asset;
  final String freezeQty;
  final String expiry;
  final String strike;
  final String optType;
  final String weekly;
  final String isin;
  final String desc;
  final String availFlag;
  final String trdUnit;

  final int holdingQty;
  final int nonPoaQty;

  final List<String> eventItems;

  @override
  List<Object?> get props => [
    id,
    spotID,
    dispName,
    instrument,
    streamSym,
    baseSym,
    exchange,
    excToken,
    series,
    lot,
    tick,
    asset,
    freezeQty,
    expiry,
    strike,
    optType,
    weekly,
    isin,
    desc,
    availFlag,
    trdUnit,
    holdingQty,
    nonPoaQty,
    eventItems,
  ];

  const Sym({
    required this.id,
    this.spotID = '',
    this.dispName = '',
    this.instrument = '',
    this.streamSym = '',
    this.baseSym = '',
    this.exchange = '',
    this.excToken = '',
    this.series = '',
    this.lot = '',
    this.tick = '',
    this.asset = '',
    this.freezeQty = '',
    this.expiry = '',
    this.strike = '',
    this.optType = '',
    this.weekly = '',
    this.isin = '',
    this.desc = '',
    this.availFlag = '',
    this.trdUnit = '',
    this.holdingQty = -1,
    this.nonPoaQty = -1,
    this.eventItems = const [],
  });

  // ignore: long-parameter-list
  Sym copyWith({
    String? id,
    String? spotID,
    String? displaySym,
    String? instrument,
    String? streamSym,
    String? baseSym,
    String? exch,
    String? excToken,
    String? series,
    String? lot,
    String? tick,
    String? asset,
    String? freezeQty,
    String? exp,
    String? strike,
    String? optType,
    String? weekly,
    String? isin,
    String? desc,
    String? availFlag,
    String? trdUnit,
    int? holdingQty,
    int? nonPoaQty,
    List<String>? eventItems,
  }) {
    return Sym(
      id: id ?? this.id,
      spotID: spotID ?? this.spotID,
      dispName: displaySym ?? dispName,
      instrument: instrument ?? this.instrument,
      streamSym: streamSym ?? this.streamSym,
      baseSym: baseSym ?? this.baseSym,
      exchange: exch ?? exchange,
      excToken: excToken ?? this.excToken,
      series: series ?? this.series,
      lot: lot ?? this.lot,
      tick: tick ?? this.tick,
      asset: asset ?? this.asset,
      freezeQty: freezeQty ?? this.freezeQty,
      expiry: exp ?? expiry,
      strike: strike ?? this.strike,
      optType: optType ?? this.optType,
      weekly: weekly ?? this.weekly,
      isin: isin ?? this.isin,
      desc: desc ?? this.desc,
      availFlag: availFlag ?? this.availFlag,
      trdUnit: trdUnit ?? this.trdUnit,
      holdingQty: holdingQty ?? this.holdingQty,
      nonPoaQty: nonPoaQty ?? this.nonPoaQty,
      eventItems: eventItems ?? this.eventItems,
    );
  }
}
