import 'package:flutter/material.dart';
import 'package:photostudio_v1/models/touch_event.dart';
// import 'package:page_curl/models/touch_event.dart';
import 'dart:math' as math;

import 'package:photostudio_v1/models/vector_2d.dart';

// import 'package:page_curl/models/vector_2d.dart';

class CurlWidget extends StatefulWidget {
  final Widget frontWidget;
  final Widget backWidget;
  final Size size;

  CurlWidget({
    @required this.frontWidget,
    @required this.backWidget,
    @required this.size,
  });

  @override
  _CurlWidgetState createState() => _CurlWidgetState();
}

class _CurlWidgetState extends State<CurlWidget> {
  /* variables that controls drag and updates */

  /* px / draw call */
  int mCurlSpeed = 60;

  /* The initial offset for x and y axis movements */
  int mInitialEdgeOffset;

  /* Maximum radius a page can be flipped, by default it's the width of the view */
  double mFlipRadius;

  /* pointer used to move */
  Vector2D mMovement;

  /* finger position */
  Vector2D mFinger;

  /* movement pointer from the last frame */
  Vector2D mOldMovement;

  /* paint curl edge */
  Paint curlEdgePaint;

  /* vector points used to define current clipping paths */
  Vector2D mA, mB, mC, mD, mE, mF, mOldF, mOrigin;

  /* ff false no draw call has been done */
  bool bViewDrawn;

  /* if TRUE we are currently auto-flipping */
  bool bFlipping;

  /* tRUE if the user moves the pages */
  bool bUserMoves;

  /* used to control touch input blocking */
  bool bBlockTouchInput = false;

  /* enable input after the next draw event */
  bool bEnableInputAfterDraw = false;

  double abs(double value) {
    if (value < 0) return value * -1;
    return value;
  }

  Vector2D capMovement(Vector2D point, bool bMaintainMoveDir) {
    // make sure we never ever move too much
    if (point.distance(mOrigin) > mFlipRadius) {
      if (bMaintainMoveDir) {
        // maintain the direction
        point = mOrigin.sum(point.sub(mOrigin).normalize().mult(mFlipRadius));
      } else {
        // change direction
        if (point.x > (mOrigin.x + mFlipRadius))
          point.x = (mOrigin.x + mFlipRadius);
        else if (point.x < (mOrigin.x - mFlipRadius))
          point.x = (mOrigin.x - mFlipRadius);
        point.y = math.sin(math.acos(abs(point.x - mOrigin.x) / mFlipRadius)) *
            mFlipRadius;
      }
    }
    return point;
  }

  void doPageCurl() {
    int width = getWidth().toInt();
    int height = getHeight().toInt();

    // F will follow the finger, we add a small displacement
    // So that we can see the edge
    mF.x = width - mMovement.x + 0.01;
    mF.y = height - mMovement.y + 0.01;

    // Set min points
    if (mA.x == 0) {
      mF.x = math.min(mF.x, mOldF.x);
      mF.y = math.max(mF.y, mOldF.y);
    }

    // Get diffs
    double deltaX = width - mF.x;
    double deltaY = height - mF.y;

    double bh = math.sqrt(deltaX * deltaX + deltaY * deltaY) / 2;
    double tangAlpha = deltaY / deltaX;
    double alpha = math.atan(deltaY / deltaX);
    double _cos = math.cos(alpha);
    double _sin = math.sin(alpha);

    mA.x = width - (bh / _cos);
    mA.y = height.toDouble();

    mD.x = width.toDouble();
    // bound mD.y
    mD.y = math.min(height - (bh / _sin), getHeight());

    mA.x = math.max(0, mA.x);
    if (mA.x == 0) {
      mOldF.x = mF.x;
      mOldF.y = mF.y;
    }

    // Get W
    mE.x = mD.x;
    mE.y = mD.y;

    // bouding corrections
    if (mD.y < 0) {
      mD.x = width + tangAlpha * mD.y;

      mE.x = width + math.tan(2 * alpha) * mD.y;

      // modify mD to create newmD by cleaning y value
      Vector2D newmD = Vector2D(mD.x, 0);
      double l = width - newmD.x;

      mE.y = -math.sqrt(abs(math.pow(l, 2) - math.pow((newmD.x - mE.x), 2)));
    }
  }

  double getWidth() => widget.size.width;

  double getHeight() => widget.size.height;

  void resetClipEdge() {
    // set base movement
    mMovement.x = mInitialEdgeOffset.toDouble();
    mMovement.y = mInitialEdgeOffset.toDouble();
    mOldMovement.x = 0;
    mOldMovement.y = 0;

    mA = Vector2D(0, 0);
    mB = Vector2D(getWidth(), getHeight());
    mC = Vector2D(getWidth(), 0);
    mD = Vector2D(0, 0);
    mE = Vector2D(0, 0);
    mF = Vector2D(0, 0);
    mOldF = Vector2D(0, 0);

    // The movement origin point
    mOrigin = Vector2D(getWidth(), 0);
  }

  void resetMovement() {
    if (!bFlipping) return;

    // No input when flipping
    bBlockTouchInput = true;

    double curlSpeed = mCurlSpeed.toDouble();
    curlSpeed *= -1;

    mMovement.x += curlSpeed;
    mMovement = capMovement(mMovement, false);

    resetClipEdge();
    doPageCurl();

    bUserMoves = true;
    bBlockTouchInput = false;
    bFlipping = false;
    bEnableInputAfterDraw = true;

    setState(() {});
  }

  void handleTouchInput(TouchEvent touchEvent) {
    if (bBlockTouchInput) return;

    if (touchEvent.getEvent() != TouchEventType.END) {
      // get finger position if NOT TouchEventType.END
      mFinger.x = touchEvent.getX();
      mFinger.y = touchEvent.getY();
    }

    switch (touchEvent.getEvent()) {
      case TouchEventType.END:
        bUserMoves = false;
        bFlipping = false;
        resetMovement();
        print("mFinger.x: ${mFinger.x} mFinger.y: ${mFinger.y}");
        break;

      case TouchEventType.START:
        mOldMovement.x = mFinger.x;
        mOldMovement.y = mFinger.y;
        break;

      case TouchEventType.MOVE:
        bUserMoves = true;

        // get movement
        mMovement.x -= mFinger.x - mOldMovement.x;
        mMovement.y -= mFinger.y - mOldMovement.y;
        mMovement = capMovement(mMovement, true);

        // make sure the y value get's locked at a nice level
        if (mMovement.y <= 1) mMovement.y = 1;

        // save old movement values
        mOldMovement.x = mFinger.x;
        mOldMovement.y = mFinger.y;

        doPageCurl();

        setState(() {});
        break;
    }
  }

  double convertRadiusToSigma(double radius) {
    return radius * 0.57735 + 0.5;
  }

  void init() {
    // init main variables

    mMovement = Vector2D(0, 0);
    mFinger = Vector2D(0, 10);
    mOldMovement = Vector2D(0, 0);

    // create the edge paint
    curlEdgePaint = Paint();
    curlEdgePaint.isAntiAlias = true;
    curlEdgePaint.color = Colors.white;
    curlEdgePaint.style = PaintingStyle.fill;

    // mUpdateRate = 1;
    mInitialEdgeOffset = 0;

    // other initializations
    mFlipRadius = getWidth() - 50;
    // mFlipRadius = 500;

    resetClipEdge();
    doPageCurl();
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  Widget boundingBox({Widget child}) => SizedBox(
        width: getWidth(),
        height: getHeight(),
        child: child,
      );

  double getAngle() {
    double displaceInX = mA.x - mF.x;
    if (displaceInX == 149.99998333333335) displaceInX = 0;

    double displaceInY = getHeight() - mF.y;
    if (displaceInY < 0) displaceInY = 0;

    double angle = math.atan(displaceInY / displaceInX);
    if (angle.isNaN) angle = 0.0;

    if (angle < 0) angle = angle + math.pi;

    angle = 0.002;
    return angle;
  }

  Offset getOffset() {
    double xOffset = mF.x;
    double yOffset = -abs(getHeight() - mF.y);

    return Offset(xOffset, yOffset);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) {
        print("mA: $mA mD: $mD mE: $mE mF: $mF");
        handleTouchInput(TouchEvent(TouchEventType.END, null));
      },
      onHorizontalDragStart: (DragStartDetails dsd) {
        handleTouchInput(TouchEvent(TouchEventType.START, dsd.localPosition));
      },
      onHorizontalDragUpdate: (DragUpdateDetails dud) {
        handleTouchInput(
          TouchEvent(TouchEventType.MOVE, dud.localPosition),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // foreground image + custom painter for shadow
          boundingBox(
            child: ClipPath(
              clipper: CurlBackgroundClipper(mA: mA, mD: mD, mE: mE, mF: mF),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  widget.frontWidget,
                  CustomPaint(
                    painter: CurlShadowPainter(mA: mA, mD: mD, mE: mE, mF: mF),
                  ),
                ],
              ),
            ),
          ),

          // back side - widget
          boundingBox(
            child: ClipPath(
              clipper: CurlBackSideClipper(mA: mA, mD: mD, mE: mE, mF: mF),
              clipBehavior: Clip.antiAlias,
              child: Transform.translate(
                offset: getOffset(),
                child: Transform.rotate(
                  alignment: Alignment.bottomLeft,
                  angle: getAngle(),
                  child: widget.backWidget,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurlBackSideClipper extends CustomClipper<Path> {
  final Vector2D mA, mD, mE, mF;

  CurlBackSideClipper({
    @required this.mA,
    @required this.mD,
    @required this.mE,
    @required this.mF,
  });

  Path createCurlEdgePath() {
    print("Back: mA $mA mD: $mD mE: $mE mF: $mF");
    Path path = Path();
    path.moveTo(mA.x, mA.y);
    path.lineTo(mD.x, math.max(0, mD.y));
    mE.y = math.max(0, mE.y);
    // mE.x > 0 ? mE.x = 148 : mE.x;
    path.lineTo(mE.x, mE.y);
    mF.x < 0 ? mE.x = -150 : mE.x = 200;
    path.lineTo(mF.x, mF.y);
    path.lineTo(mA.x, mA.y);

    return path;
  }

  @override
  Path getClip(Size size) {
    return createCurlEdgePath();
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return true;
  }
}

class CurlBackgroundClipper extends CustomClipper<Path> {
  final Vector2D mA, mD, mE, mF;

  CurlBackgroundClipper({
    @required this.mA,
    @required this.mD,
    @required this.mE,
    @required this.mF,
  });

  Path createBackgroundPath(Size size) {
    Path path = Path();

    path.moveTo(0, 0);
    // print("mE: $mE");
    // if (mE.x != size.width)
    // mE.y = 1;
    // path.lineTo(mE.x, mE.y);
    // else
    path.lineTo(size.width, 0);
    path.lineTo(mD.x, math.max(0, mD.y));
    path.lineTo(mA.x, mA.y);
    path.lineTo(0, size.height);
    if (mF.x < 0) path.lineTo(mF.x, mF.y);
    path.lineTo(0, 0);

    return path;
  }

  @override
  Path getClip(Size size) {
    return createBackgroundPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return true;
  }
}

class CurlShadowPainter extends CustomPainter {
  Vector2D mA, mD, mE, mF;

  CurlShadowPainter({
    @required this.mA,
    @required this.mD,
    @required this.mE,
    @required this.mF,
  });

  Path getShadowPath(int t) {
    // mE.x -= 20;
    Path path = Path();
    path.moveTo(mA.x - t + 10, mA.y);
    path.lineTo(mD.x, math.max(0, mD.y - t));
    path.lineTo(mE.x, mE.y - t);
    if (mF.x < 0)
      path.lineTo(-t.toDouble(), mF.y - t);
    else
      path.lineTo(mF.x - t, mF.y - t);
    path.moveTo(mA.x - t, mA.y);

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    print("Shadow: mA: $mA mD: $mD mE: $mE mF: $mF");
    if (mF.x != 0.0) {
      // only draw shadow when pulled
      final double shadowElev = 10.0;
      canvas.drawShadow(
        getShadowPath(shadowElev.toInt()),
        Colors.black,
        shadowElev,
        true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
