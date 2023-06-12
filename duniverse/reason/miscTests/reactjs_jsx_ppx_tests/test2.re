[@bs.config {foo, jsx: 2}];

/* test setup dummy modules. These are here to make the transform pass the type checker. Also helps validating our transforms thanks to types */

module ReactDOMRe = {
  let createElement = (tag, ~props=?, children: array('a)) => 1;
  let createElementVariadic = (tag, ~props=?, children: array('a)) => 1;
  let props = (~className=?, ~width=?, ~comp=?, ~compCallback=?, ()) => 1;
};

module Foo = {
  let make = (~className=?, ~width=?, ~comp=?, ~bar=?, children) => 1;
  let createElement = (~className=?, ~ref=?, ~key=?, ~width=?, ~comp=?, ~bar=?, ~children, ()) => 1;
  module Bar = {
    let make = (~className=?, children) => 1;
    let createElement = (~className=?, ~ref=?, ~key=?, ~children, ()) => 1;
  };
};

module Bar = {
  let make = (~bar=?, children) => 1;
  let createElement = (~bar=?, ~children, ()) => 1;
};

module ReasonReact = {
  let element = (~key=?, ~ref=?, component) => 1;
  let fragment = (children: array('a)) => 1;
};

let divRef = <div />;
let divRefs = [|<div />|];

"=== DOM component ===";

<div />;

<div className="hello" />;

<div className="hello" width="10" />;

<div className="hello" width="10"> (<li> <p/> </li>) (<Foo> <Bar /> </Foo>) </div>;

<div className="hello" comp=(<Foo bar=1 />)> <li /> <Foo bar=2 /> </div>;

<div className="hello" compCallback=(fun () => <Foo bar=1 />)> <li /> ((fun () => <Foo bar=2 />) ()) </div>;

"=== Custom component ===";

<Foo />;

<Foo> <div /> </Foo>;

<Foo> <Bar /> </Foo>;

<Foo> <div /> <Bar /> </Foo>;

<Foo> divRef divRef </Foo>;

<Foo className="hello" />;

<Foo className="hello"> <div /> </Foo>;

<Foo className="hello"> <Bar /> </Foo>;

<Foo className="hello"> <div /> <Bar /> </Foo>;

<Foo className="hello"> divRef divRef </Foo>;

<Foo className="hello" width="10" />;

<Foo className="hello" width="10"> (<li> <p/> </li>) (<Foo> <Bar /> </Foo>) </Foo>;

<Foo className="hello" comp=(<Bar bar=1 />)> <li /> <Bar bar=2 /> </Foo>;

<Foo comp=(<Bar> divRef divRef </Bar>)> <li /> </Foo>;

<Foo comp=(<Bar> <div /> </Bar>)> <li /> </Foo>;

"=== No wrapping for single child ===";

<Foo> ...(() => 1) </Foo>;

<Foo> ...(() => (<Bar />)) </Foo>;

<Foo> ...(1, 2) </Foo>;

<Foo> ...[|1|] </Foo>;

<Foo> ...[||] </Foo>;

<Foo> ...[] </Foo>;

<Foo> ...divRef </Foo>;

<Foo> ...<div /> </Foo>;

<Foo> ...<Bar /> </Foo>;

<Foo className="hello"> ...(() => 1) </Foo>;

<Foo className="hello"> ...(1, 2) </Foo>;

<Foo className="hello"> ...[|1, 2|] </Foo>;

<Foo className="hello"> ...divRef </Foo>;

<Foo comp=(<Bar> ...divRef </Bar>)> ...<li /> </Foo>;

<div comp=(<Bar> ...divRef </Bar>)> </div>;

"=== Special transform for DOM component with a single child spread ===";

<div> ...divRefs </div>;

<div> ...((() => divRefs)()) </div>;

<div className="hi"> ...divRefs </div>;

<div className="hi"> ...((() => divRefs)()) </div>;

<div> ...[] </div>;

<div> ...[<div />] </div>;

"=== With ref/key ===";

<Foo key="someKey" className="hello" />;

<Foo key=(Some("someKey")) ref=(Some(ref)) className="hello" />;

<Foo key=?(Some("someKey")) ref=?(Some(ref)) className="hello" />;

<Foo.Bar key="someKey" ref=(Some(ref)) className="hello"> <Bar /> </Foo.Bar>;

/* Upcoming JSX syntax (pre-ppx) will desugar to Foo.make instad of
  Foo.createElement. Future-proof it in the ppx by transforming both to the
  correct ReasonReact-specific call */

([@JSX] Foo.make(~children=[], ()));

"=== Fragment ===";

<> </>;

<> 1 </>;

<> <> <div /> </> </>;

<> <> </> 2 </>;

<> <Foo> 1 </Foo> </>;

<> <div comp=(<Bar> ...divRef </Bar>)> </div> </>;
