import App

#if DEBUG
import Backtrace
// Do this first
Backtrace.install()
#endif

try app(.detect()).run()
