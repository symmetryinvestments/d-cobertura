module cobertura;

import std.typecons : Nullable, nullable;
import std.traits : isSomeString, isCallable;
import std.range : isInputRange, ElementType;

struct LineCoverage {
	size_t index;
	size_t count;
}

struct FileCoverage {
	string path;
	LineCoverage[] lines;
	size_t linesCovered;
}

FileCoverage parseLstFile(string path) {
	import std.stdio : File;
	return parseLstFile(File(path).byLine, path);
}

template tryTo(T) {
	Nullable!T tryTo(R)(R r) {
		import std.conv : to;
		try {
			return nullable(r.to!T);
		} catch (Exception e) {
			return Nullable!T.init;
		}
	}
}

private template andThen(alias fun) {
    auto andThen(T)(Nullable!T t) {
        alias RT = typeof(fun(T.init));
        static if (is(RT == void)) {
            if (!t.isNull) {
                fun(t.get);
			}
        } else {
            alias Result = Nullable!RT;
            if (t.isNull) {
                return Result.init;
			}
            return Result(fun(t.get));
        }
    }
}

FileCoverage parseLstFile(Lines)(Lines r, string path) if (isInputRange!Lines &&
													   isSomeString!(ElementType!Lines)) {
	import std.range : enumerate, tee;
	import std.algorithm : map, stripLeft, until, filter;
	import std.array : array;
	size_t linesCovered = 0;
	auto lines = r.enumerate.map!((line){
			return line
				.value
				.stripLeft(' ')
				.until('|')
				.tryTo!size_t
				.andThen!(v => LineCoverage(line.index, v));
		})
	    .filter!(a => !a.isNull).map!(a => a.get)
		.tee!(line => linesCovered += (line.count > 0))
		.array();
	return FileCoverage(path, lines, linesCovered);
 }

unittest {
	import unit_threaded;
	import std.string;
	testLst
		.splitLines
		.parseLstFile("file").should == FileCoverage("file", [LineCoverage(9, 1), LineCoverage(13, 0), LineCoverage(14, 0), LineCoverage(15, 0), LineCoverage(19, 0)], 1);
}

auto generateXmlFile(FileCoverage[] files) {
	import core.stdc.time: time;
	import std.format: format;
	import std.path: buildPath;

	import std.algorithm.iteration: splitter, map, sum;

	size_t linesValid = files.map!(file => file.lines.length).sum();
	size_t linesCovered = files.map!(file => file.linesCovered).sum();

	double lineRate = cast(double)linesCovered / linesValid;

	string res = `<?xml version="1.0"?>
<coverage version="5.3"
	timestamp="%s"
	lines-valid="%s"
	lines-covered="%s"
	line-rate="%s"
	branches-covered="0"
	branches-valid="0"
	branch-rate="0"
	complexity="0"
>
`.format(time(null), linesValid, linesCovered, lineRate);

	res ~= "\t<sources>\n\t\t<source>./</source>\n\t</sources>\n";
	res ~=
		`	<packages>
`;
	foreach(file; files) {
		lineRate = cast(double)file.linesCovered / file.lines.length;

		string fpath = buildPath(file.path[0 .. $-4].splitter('-')) ~ ".d";

		res ~=
			`		<package name="covered" line-rate="%1$s" branch-rate="0" complexity="0">
			<classes>
				<class name="%2$s" filename="%2$s" complexity="0" line-rate="%1$s" branch-rate="0"><methods></methods>
`.format(lineRate, fpath);

		res ~= "\t\t\t\t\t<lines>\n";
		foreach(line; file.lines) {
			res ~= "\t\t\t\t\t\t<line number=\"%s\" hits=\"%s\"/>\n".format(line.index+1, line.count);
		}
		res ~= "\t\t\t\t\t</lines>\n\t\t\t\t</class>\n\t\t\t</classes>\n\t\t</package>\n\t";
	}
	res ~= "</packages>\n</coverage>";
	return res;
}

unittest {
	import unit_threaded;
	import std.string;
	import std.regex;
	auto files = [testLst
				  .splitLines
				  .parseLstFile("file")];
	files.generateXmlFile()
		.replace(regex("timestamp=\"[0-9]+\""), "timestamp=\"filtered\"")
		.should == `<?xml version="1.0"?>
<coverage version="5.3"
	timestamp="filtered"
	lines-valid="5"
	lines-covered="1"
	line-rate="0.2"
	branches-covered="0"
	branches-valid="0"
	branch-rate="0"
	complexity="0"
>
	<sources>
		<source>./</source>
	</sources>
	<packages>
		<package name="covered" line-rate="0.2" branch-rate="0" complexity="0">
			<classes>
				<class name=".d" filename=".d" complexity="0" line-rate="0.2" branch-rate="0"><methods></methods>
					<lines>
						<line number="10" hits="1"/>
						<line number="14" hits="0"/>
						<line number="15" hits="0"/>
						<line number="16" hits="0"/>
						<line number="20" hits="0"/>
					</lines>
				</class>
			</classes>
		</package>
	</packages>
</coverage>`;
}

version(unittest) enum testLst = `       |module foobar;
       |
       |struct FooBar(T, string memberName) {
       |    import core.sync.mutex : Mutex;
       |
       |    private static shared T _val__;
       |    private static shared Mutex _m__;
       |
       |    shared static this() {
      1|        _m__ = new shared Mutex();
       |    }
       |
       |    static typeof(this)opCall() {
0000000|        typeof(this)tmp;
0000000|        tmp._m__.lock_nothrow();
0000000|        return tmp;
       |    }
       |
       |    ~this() {
0000000|        _m__.unlock_nothrow();
       |    }
       |
       |
       |    this(this) @disable;
       |}`;
