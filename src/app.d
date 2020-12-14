import std.stdio;
import std.file;
import std.algorithm.iteration: map, reduce;
import std.array: array, split;
import std.conv: parse;

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
		assert(path.ends_with(".lst"));
		this.path = path;

		size_t i = 0;
		this.lines = File(path)
			.byLineCopy
			.map!((x) {
				i++;
				Line l = {relevant:false};
				try {
					l.times_covered = parse!uint(x.split('|')[0]);
					l.relevant = true;
					indices ~= i;
				} catch{}
				return l;})
			.array;
	}

	string xml_dump() {
		import core.stdc.time: time;
		import std.format: fmt = format;
		import std.path: dir_name = dirName, base_name = baseName, build_path = buildPath, absolute = absolutePath;
		import std.algorithm.iteration: splitter;
		double line_rate = indices.length/cast(double)lines.length;
		string res = `<?xml version="1.0"?>
<coverage version="5.3" timestamp="%s" lines-valid="%s" lines-covered="%s" line-rate="%s" branches-covered="0" branches-valid="0" branch-rate="0" complexity="0">`.fmt(time(null), lines.length, indices.length, line_rate);
		string fpath = build_path(path[0 .. $-4].splitter('-')) ~ ".d";
		res ~= `<sources><source>%s</source></sources>`.fmt(path.dir_name.absolute);
		res ~= `<packages><package name="covered" line-rate="%1$s" branch-rate="0" complexity="0"><classes><class name="%2$s" filename="%2$s" complexity="0" line-rate="%1$s" branch-rate="0"><methods/>`.fmt(line_rate, fpath);

		res ~= `<lines>`;
		foreach (i; indices) res ~= `<line number="%s" hits="%s"/>`.fmt(i, lines[i].times_covered);
		res ~= `</lines></class></classes></package></packages></coverage>`;
		return res;
	}
}

int main(string[] args) {
	import std.path: relative_path = relativePath;
	if (args.length < 2) {
		writefln("Usage: %s <coverages.lst>");
		return 1;
	}

	foreach (fn; args[1 .. $]) {
		import std.file: fspurt = write;
		auto c = CoveredFile(fn.relative_path);
		fspurt(fn[0 .. $-3] ~ "xml", c.xml_dump);
	}

	return 0;
}
