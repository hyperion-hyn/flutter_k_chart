import 'dart:async';

import 'package:flutter/material.dart';
import 'chart_style.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'renderer/chart_painter.dart';
import 'utils/date_format_util.dart';
import 'utils/number_util.dart';

enum MainState { MA, BOLL, NONE }
enum VolState { VOL, NONE }
enum SecondaryState { MACD, KDJ, RSI, WR, NONE }

class KChartWidget extends StatefulWidget {
  final List<KLineEntity> datas;
  final MainState mainState;
  final VolState volState;
  final SecondaryState secondaryState;
  final bool isLine;
  final String locale;

  KChartWidget(
    this.datas, {
    this.mainState = MainState.MA,
    this.volState = VolState.VOL,
    this.secondaryState = SecondaryState.MACD,
    this.isLine,
    int fractionDigits = 2,
    this.locale = "zh_CN",
  }) {
    NumberUtil.fractionDigits = fractionDigits;
  }

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _animation;
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity> mInfoWindowStream;
  double mWidth = 0;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity>();
    _controller = AnimationController(duration: Duration(milliseconds: 850), vsync: this);
    _animation = Tween(begin: 0.9, end: 0.1).animate(_controller)..addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mWidth = MediaQuery.of(context).size.width;

    /*
    {
      "date": "时间",
    "open": "开",
    "high": "高",
    "low": "低",
    "close": "收",
    "down_up": "涨跌额",
    "down_down": "涨幅",
    "amount": "成交量"
    }
    */

    var date = "时间";
    var open = "开";
    var high = "高";
    var low = "低";
    var close = "收";
    var downUp = "涨跌额";
    var downDown = "涨幅";
    var amount = "成交量";
    print("[object] widget.locale.languageCode:${widget.locale}");

    switch (widget.locale) {
      case "zh_CN":
        date = "时间";
        open = "开";
        high = "高";
        low = "低";
        close = "收";
        downUp = "涨跌额";
        downDown = "涨幅";
        amount = "成交量";
        break;

      case "zh_HK":
        date = "時間";
        open = "開";
        high = "高";
        low = "低";
        close = "收";
        downUp = "漲跌額";
        downDown = "漲幅";
        amount = "成交量";
        break;

      case "ko":
        date = "시간";
        open = "열기";
        high = "높음";
        low = "낮음";
        close = "닫기";
        downUp = "변화량";
        downDown = "증가";
        amount = "거래량";
        break;

      case "en":
        date = "Time";
        open = "Open";
        high = "High";
        low = "Low";
        close = "Close";
        downUp = "Change";
        downDown = "Increase";
        amount = "Volume";

        break;
    }
    infoNames = [date, open, high, low, close, downUp, downDown, amount];
  }

  @override
  void didUpdateWidget(KChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.datas != widget.datas) mScrollX = mSelectX = 0.0;
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas == null || widget.datas.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    return GestureDetector(
      onHorizontalDragDown: (details) {
        isDrag = true;
      },
      onHorizontalDragUpdate: (details) {
        if (isScale || isLongPress) return;
        mScrollX = (details.primaryDelta / mScaleX + mScrollX).clamp(0.0, ChartPainter.maxScrollX);
        notifyChanged();
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        isDrag = false;
      },
      onHorizontalDragCancel: () => isDrag = false,
      onScaleStart: (_) {
        isScale = true;
      },
      onScaleUpdate: (details) {
        if (isDrag || isLongPress) return;
        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        notifyChanged();
      },
      onScaleEnd: (_) {
        isScale = false;
        _lastScale = mScaleX;
      },
      onLongPressStart: (details) {
        isLongPress = true;
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressEnd: (details) {
        isLongPress = false;
        mInfoWindowStream?.sink?.add(null);
        notifyChanged();
      },
      child: Stack(
        children: <Widget>[
          CustomPaint(
            size: Size(double.infinity, double.infinity),
            painter: ChartPainter(
                datas: widget.datas,
                scaleX: mScaleX,
                scrollX: mScrollX,
                selectX: mSelectX,
                isLongPass: isLongPress,
                mainState: widget.mainState,
                volState: widget.volState,
                secondaryState: widget.secondaryState,
                isLine: widget.isLine,
                sink: mInfoWindowStream?.sink,
                opacity: _animation.value,
                controller: _controller),
          ),
          _buildInfoDialog()
        ],
      ),
    );
  }

  void notifyChanged() => setState(() {});

  List<String> infoNames = ["时间", "开", "高", "低", "收", "涨跌额", "涨幅", "成交量"];
  List infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if (!isLongPress || widget.isLine == true || !snapshot.hasData || snapshot.data.kLineEntity == null)
            return Container();
          KLineEntity entity = snapshot.data.kLineEntity;
          double upDown = entity.close - entity.open;
          double upDownPercent = upDown / entity.open * 100;
          infos = [
            getDate(entity.id),
            NumberUtil.format(entity.open),
            NumberUtil.format(entity.high),
            NumberUtil.format(entity.low),
            NumberUtil.format(entity.close),
            "${upDown > 0 ? "+" : ""}${NumberUtil.format(upDown)}",
            "${upDownPercent > 0 ? "+" : ''}${upDownPercent.toStringAsFixed(2)}%",
            NumberUtil.volFormat(entity.vol)
          ];
          return Align(
            alignment: snapshot.data.isLeft ? Alignment.topLeft : Alignment.topRight,
            child: Container(
              margin: EdgeInsets.only(left: 10, right: 10, top: 25),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: ChartColors.markerBgColor,
                border: Border.all(color: ChartColors.markerBorderColor, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(infoNames.length, (i) => _buildItem(infos[i].toString(), infoNames[i])),
              ),
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = ChartColors.selectedTextColor;
    if (info.startsWith("+"))
      color = Colors.green;
    else if (info.startsWith("-"))
      color = Colors.red;
    else
      color = ChartColors.selectedTextColor;
    return Container(
      constraints: BoxConstraints(minWidth: 95, maxWidth: 110, maxHeight: 14.0, minHeight: 14.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text("$infoName",
              style: TextStyle(
                  color: ChartColors.selectedTextColor,
                  fontSize: ChartStyle.defaultTextSize,
                  fontWeight: FontWeight.w500)),
          SizedBox(width: 5),
          Text(info, style: TextStyle(color: color, fontSize: ChartStyle.defaultTextSize, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String getDate(int date) {
    return dateFormat(DateTime.fromMillisecondsSinceEpoch(date * 1000), [yy, '-', mm, '-', dd, ' ', HH, ':', nn]);
  }
}
