import std.stdio;
import std.file;
import std.algorithm.iteration: map, reduce;
import std.array: array, split;
import std.conv: to;

struct Line {
	uint times_covered;
	bool relevant;
}

struct CoveredFile {
	string path;
	Line[] lines;
	size_t[] indices; // indices of lines that were covered
	this(string path) {
		import std.algorithm.searching: ends_with = endsWith;
		import std.string : strip;

		assert(path.ends_with(".lst"));
		this.path = path;

		size_t i = 0;
		this.lines = File(path)
			.byLineCopy
			.map!((x) {
				i++;
				Line l = {relevant:false};
				try {
					string s = x.split('|')[0].strip;
					l.times_covered = s.to!uint();
					l.relevant = true;
					indices ~= i;
				} catch(Exception e) {
				}
				return l;
			})
			.array;
	}

	string xml_dump(string prefix) {
		import core.stdc.time: time;
		import std.format: fmt = format;
		import std.path: base_name = baseName, build_path = buildPath
			, build_path = buildPath, absolute = absolutePath
			, is_absolute = isAbsolute;

		import std.algorithm.iteration: splitter;

		double line_rate = indices.length / cast(double)lines.length;

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
`.fmt(time(null), lines.length, indices.length, line_rate);

		string fpath = build_path(path[0 .. $-4].splitter('-')) ~ ".d";
		res ~= "\t<sources>\n\t\t<source>./</source>\n\t</sources>\n";
		res ~=
`	<packages>
		<package name="covered" line-rate="%1$s" branch-rate="0" complexity="0">
			<classes>
				<class name="%2$s" filename="%2$s" complexity="0" line-rate="%1$s" branch-rate="0">
`.fmt(line_rate, fpath);

		res ~= "\t\t\t\t\t<lines>\n";
		foreach(i; indices) {
			res ~= "\t\t\t\t\t\t<line number=\"%s\" hits=\"%s\"/>\n".fmt(i, lines[i].times_covered);
		}
		res ~= "\t\t\t\t\t</lines>\n\t\t\t\t</class>\n\t\t\t</classes>\n\t\t</package>\n\t</packages>\n</coverage>";
		return res;
	}
}

int main(string[] args) {
	import std.path: relative_path = relativePath;
	if (args.length < 3) {
		writefln("Usage: <prefix> <coverages.lst>");
		return 1;
	}

	foreach (fn; args[2 .. $]) {
		import std.file: fspurt = write;
		auto c = CoveredFile(fn.relative_path);
		fspurt(fn[0 .. $-3] ~ "xml", c.xml_dump(args[1]));
	}

	return 0;
}
