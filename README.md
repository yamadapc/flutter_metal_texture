# flutter_texture_example
![](./screenshot.png)

Demo metal texture rendering within flutter app.

Some parts were based on https://github.com/mogol/opengl_texture_widget_example

## CPU Usage
CPU usage hovers around 16% on my computer to tick the render loop. Most of the time is
spent in Flutter's internal rendering code.

One improvement would be to stop the render loop when an app goes into the
background.