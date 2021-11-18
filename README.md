# flutter_texture_example
> Demo metal texture rendering within flutter app.
>
> _Note: the GIF is janky, but that's due to the GIF being a GIF_

<p align="center">
  <img height="500" src="demo.gif" alt="Flutter Metal Texture Demo GIF"/>
</p>

Flutter renders widgets, one of which is a `Texture` widget. It sends a message to
the Swift host, which creates a `CVPixelBuffer` linked to a metal `MTLTexture`.

It then starts a render-loop, linked to the display refresh rate with `CVDisplayLink`
and renders a quad with a mock increasing tick uniform.

The idea is to benchmark and spike using flutter for widget rendering while having
visuals rendered using a different strategy.

Some parts were based on https://github.com/mogol/opengl_texture_widget_example

## CPU Usage
> Not a proper measurement, just quick glancing at the activity monitor.
> 
> Flutter version: 2.8.0-3.1.pre

Performance seems fine, but CPU usage is relatively high.

Rendering `Texture(textureId: id)` linked to the display's frame-rate causes
CPU usage to hover at around 16% on my computer to tick the render loop.

For reference, an empty view app uses 2% CPU idle.

Most of the time is spent in Flutter's internal rendering code.

Wrapping its tree on a `RepaintBoundary` seems to improve this by 2-4%.

One improvement would be to stop the render loop when an app goes into the
background.

Rendering 5 textures at the same time pushes CPU up to around 30%. It might be
possible to say each texture after the first is causing a ~4% CPU usage
increase.

I'd imagine some CPU usage is caused by the Swift render loop I wrote & could be
optimised a bit more.

![](./screenshot.png)
