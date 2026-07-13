## Abstract

Web Content Accessibility Guidelines \(WCAG\) 2.2 covers a wide range of recommendations for making web content more accessible. Following these guidelines will make content more accessible to a wider range of people with disabilities, including accommodations for blindness and low vision, deafness and hearing loss, limited movement, speech disabilities, photosensitivity, and combinations of these, and some accommodation for learning disabilities and cognitive limitations; but will not address every user need for people with these disabilities. These guidelines address accessibility of web content on any kind of device \(including desktops, laptops, kiosks, and mobile devices\). Following these guidelines will also often make web content more usable to users in general.

WCAG 2.2 success criteria are written as testable statements that are not technology-specific. Guidance about satisfying the success criteria in specific technologies, as well as general information about interpreting the success criteria, is provided in separate documents. See Web Content Accessibility Guidelines \(WCAG\) Overview for an introduction and links to WCAG technical and educational material.

WCAG 2.2 extends Web Content Accessibility Guidelines 2.1 \[ WCAG21 \], which was published as a W3C Recommendation June 2018. Content that conforms to WCAG 2.2 also conforms to WCAG 2.0 and WCAG 2.1. The WG intends that for policies requiring conformance to WCAG 2.0 or WCAG 2.1, WCAG 2.2 can provide an alternate means of conformance. The publication of WCAG 2.2 does not deprecate or supersede WCAG 2.0 or WCAG 2.1. While WCAG 2.0 and WCAG 2.1 remain W3C Recommendations, the W3C advises the use of WCAG 2.2 to maximize future applicability of accessibility efforts. The W3C also encourages use of the most current version of WCAG when developing or updating web accessibility policies.

## Status of This Document

This section describes the status of this document at the time of its publication. A list of current W3C publications and the latest revision of this technical report can be found in the W3C technical reports index at https://www.w3.org/TR/.

To comment, file an issue in the W3C WCAG GitHub repository . Although the proposed success criteria in this document reference issues tracking discussion, the Working Group requests that public comments be filed as new issues, one issue per discrete comment. It is free to create a GitHub account to file issues. If filing issues in GitHub is not feasible, send email to public-agwg-comments@w3.org \( comment archive \).

This document was published by the Accessibility Guidelines Working Group as a Recommendation using the Recommendation track .

W3C recommends the wide deployment of this specification as a standard for the Web.

A W3C Recommendation is a specification that, after extensive consensus-building, is endorsed by W3C and its Members, and has commitments from Working Group members to royalty-free licensing for implementations.

This document was produced by a group operating under the W3C Patent Policy . W3C maintains a public list of any patent disclosures made in connection with the deliverables of the group; that page also includes instructions for disclosing a patent. An individual who has actual knowledge of a patent which the individual believes contains Essential Claim\(s\) must disclose the information in accordance with section 6 of the W3C Patent Policy .

This document is governed by the 03 November 2023 W3C Process Document .

## Introduction

This section is non-normative.

### Background on WCAG 2

Web Content Accessibility Guidelines \(WCAG\) 2.2 defines how to make web content more accessible to people with disabilities. Accessibility involves a wide range of disabilities, including visual, auditory, physical, speech, cognitive, language, learning, and neurological disabilities. Although these guidelines cover a wide range of issues, they are not able to address the needs of people with all types, degrees, and combinations of disability. These guidelines also make web content more usable by older individuals with changing abilities due to aging and often improve usability for users in general.

WCAG 2.2 is developed through the W3C process in cooperation with individuals and organizations around the world, with a goal of providing a shared standard for web content accessibility that meets the needs of individuals, organizations, and governments internationally. WCAG 2.2 builds on WCAG 2.0 \[ WCAG20 \] and WCAG 2.1 \[ WCAG21 \], which in turn built on WCAG 1.0 \[ WAI-WEBCONTENT \] and is designed to apply broadly to different web technologies now and in the future, and to be testable with a combination of automated testing and human evaluation. For an introduction to WCAG, see the Web Content Accessibility Guidelines \(WCAG\) Overview .

Significant challenges were encountered in defining additional criteria to address cognitive, language, and learning disabilities, including a short timeline for development as well as challenges in reaching consensus on testability, implementability, and international considerations of proposals. Work will carry on in this area in future versions of WCAG. We encourage authors to refer to our supplemental guidance on improving inclusion for people with disabilities, including learning and cognitive disabilities, people with low-vision, and more .

Web accessibility depends not only on accessible content but also on accessible web browsers and other user agents. Authoring tools also have an important role in web accessibility. For an overview of how these components of web development and interaction work together, see:

- Essential Components of Web Accessibility
- User Agent Accessibility Guidelines \(UAAG\) Overview
- Authoring Tool Accessibility Guidelines \(ATAG\) Overview

Where this document refers to WCAG 2 it is intended to mean any and all versions of WCAG that start with 2.

### WCAG 2 Layers of Guidance

The individuals and organizations that use WCAG vary widely and include web designers and developers, policy makers, purchasing agents, teachers, and students. In order to meet the varying needs of this audience, several layers of guidance are provided including overall principles , general guidelines , testable success criteria and a rich collection of sufficient techniques , advisory techniques , and documented common failures with examples, resource links and code.

Principles - At the top are four principles that provide the foundation for web accessibility: perceivable, operable, understandable, and robust . See also Understanding the Four Principles of Accessibility .

Guidelines - Under the principles are guidelines. The 13 guidelines provide the basic goals that authors should work toward in order to make content more accessible to users with different disabilities. The guidelines are not testable, but provide the framework and overall objectives to help authors understand the success criteria and better implement the techniques.

Success Criteria - For each guideline, testable success criteria are provided to allow WCAG 2.2 to be used where requirements and conformance testing are necessary such as in design specification, purchasing, regulation, and contractual agreements. In order to meet the needs of different groups and different situations, three levels of conformance are defined: A \(lowest\), AA, and AAA \(highest\). Additional information on WCAG levels can be found in Understanding Levels of Conformance .

Sufficient and Advisory Techniques - For each of the guidelines and success criteria in the WCAG 2.2 document itself, the working group has also documented a wide variety of techniques . The techniques are informative and fall into two categories: those that are sufficient for meeting the success criteria and those that are advisory . The advisory techniques go beyond what is required by the individual success criteria and allow authors to better address the guidelines. Some advisory techniques address accessibility barriers that are not covered by the testable success criteria. Where common failures are known, these are also documented. See also Sufficient and Advisory Techniques in Understanding WCAG 2.2 .

All of these layers of guidance \(principles, guidelines, success criteria, and sufficient and advisory techniques\) work together to provide guidance on how to make content more accessible. Authors are encouraged to view and apply all layers that they are able to, including the advisory techniques, in order to best address the needs of the widest possible range of users.

Note that even content that conforms at the highest level \(AAA\) will not be accessible to individuals with all types, degrees, or combinations of disability, particularly in the cognitive, language, and learning areas. Authors are encouraged to consider the full range of techniques, including the advisory techniques, Making Content Usable for People with Cognitive and Learning Disabilities , as well as to seek relevant advice about current best practice to ensure that web content is accessible, as far as possible, to this community. Metadata may assist users in finding content most suitable for their needs.

### WCAG 2.2 Supporting Documents

The WCAG 2.2 document is designed to meet the needs of those who need a stable, referenceable technical standard. Other documents, called supporting documents, are based on the WCAG 2.2 document and address other important purposes, including the ability to be updated to describe how WCAG would be applied with new technologies. Supporting documents include:

How to Meet WCAG 2.2 - A customizable quick reference to WCAG 2.2 that includes all of the guidelines, success criteria, and techniques for authors to use as they are developing and evaluating web content. This includes content from WCAG 2.0, 2.1, and 2.2, and can be filtered in many ways to help authors focus on relevant content.

Understanding WCAG 2.2 - A guide to understanding and implementing WCAG 2.2. There is a short "Understanding" document for each guideline and success criterion in WCAG 2.2 as well as key topics.

Techniques for WCAG 2.2 - A collection of techniques and common failures, each in a separate document that includes a description, examples, code and tests.

The WCAG 2 Documents - A brief introduction to the WCAG 2 supporting documents and supplemental guidance.

What's New in WCAG 2.2 introduces the new success criteria with persona quotes that illustrate the accessibility issues.

See Web Content Accessibility Guidelines \(WCAG\) Overview for a description of the WCAG 2.2 supporting material, including education resources related to WCAG 2. Additional resources covering topics such as the business case for web accessibility, planning implementation to improve the accessibility of websites, and accessibility policies are listed in WAI Resources .

### Requirements for WCAG 2.2

WCAG 2.2 meets a set of requirements for WCAG 2.2 which, in turn, inherit requirements from previous WCAG 2 versions. Requirements structure the overall framework of guidelines and ensure backwards compatibility. The Working Group also used a less formal set of acceptance criteria for success criteria, to help ensure success criteria are similar in style and quality to those in WCAG 2.0. These requirements constrained what could be included in WCAG 2.2. This constraint was important to preserve its nature as a dot-release of WCAG 2.

### Comparison with WCAG 2.1

WCAG 2.2 was initiated with the goal to continue the work of WCAG 2.1: Improving accessibility guidance for three major groups: users with cognitive or learning disabilities, users with low vision, and users with disabilities on mobile devices. Many ways to meet these needs were proposed and evaluated, and a set of these were refined by the Working Group. Structural requirements inherited from WCAG 2.0, clarity and impact of proposals, and timeline led to the final set of success criteria included in this version. The Working Group considers that WCAG 2.2 incrementally advances web content accessibility guidance for all these areas, but underscores that not all user needs are met by these guidelines.

WCAG 2.2 builds on and is backwards compatible with WCAG 2.1, meaning web pages that conform to WCAG 2.2 are at least as accessible as pages that conform to WCAG 2.1. Requirements have been added that build on 2.1 and 2.0. WCAG 2.2 has removed one success criterion, 4.1.1 Parsing . Authors that are required by policy to conform with WCAG 2.0 or 2.1 will be able to update content to WCAG 2.2, but may need to continue to test and report 4.1.1. Authors following more than one version of the guidelines should be aware of the following additions.

#### New Features in WCAG 2.2

WCAG 2.2 extends WCAG 2.1 by adding new success criteria, definitions to support them, and guidelines to organize the additions. This additive approach helps to make it clear that sites which conform to WCAG 2.2 also conform to WCAG 2.1. The Accessibility Guidelines Working Group recommends that sites adopt WCAG 2.2 as their new conformance target, even if formal obligations mention previous versions, to provide improved accessibility and to anticipate future policy changes.

The following success criteria are new in WCAG 2.2:

- 2.4.11 Focus Not Obscured \(Minimum\) \(AA\)
- 2.4.12 Focus Not Obscured \(Enhanced\) \(AAA\)
- 2.4.13 Focus Appearance \(AAA\)
- 2.5.7 Dragging Movements \(AA\)
- 2.5.8 Target Size \(Minimum\) \(AA\)
- 3.2.6 Consistent Help \(A\)
- 3.3.7 Redundant Entry \(A\)
- 3.3.8 Accessible Authentication \(Minimum\) \(AA\)
- 3.3.9 Accessible Authentication \(Enhanced\) \(AAA\)

The new success criteria may reference new terms that have also been added to the glossary and form part of the normative requirements of the success criteria.

WCAG 2.2 also introduces new sections detailing aspects of the specification which may impact privacy and security .

#### Numbering in WCAG 2.2

In order to avoid confusion for implementers for whom backwards compatibility to WCAG 2 versions is important, new success criteria in WCAG 2.2 have been appended to the end of the set of success criteria within their guideline. This avoids the need to change the section number of success criteria from WCAG 2, which would be caused by inserting new success criteria between existing success criteria in the guideline, but it means success criteria in each guideline are no longer grouped by conformance level. The order of success criteria within each guideline does not imply information about conformance level; only the conformance level indicator \(A / AA / AAA\) on the success criterion itself indicates this. The WCAG 2.2 Quick Reference will provide a way to view success criteria grouped by conformance level, along with many other filter and sort options.

#### Conformance to WCAG 2.2

WCAG 2.2 uses the same conformance model as WCAG 2.0. It is intended that sites that conform to WCAG 2.2 also conform to WCAG 2.0 and WCAG 2.1, which means they meet the requirements of any policies that reference WCAG 2.0 or WCAG 2.1, while also better meeting the needs of users on the current Web.

### Later Versions of Accessibility Guidelines

In parallel with WCAG 2.2, the Accessibility Guidelines Working Group is developing another major version of accessibility guidelines. The result of this work is expected to be a more substantial restructuring of web accessibility guidance than would be realistic for dot-releases of WCAG 2. The work follows a research-focused, user-centered design methodology to produce the most effective and flexible outcome, including the roles of content authoring, user agent support, and authoring tool support. This is a multi-year effort, so WCAG 2.2 is needed as an interim measure to provide updated web accessibility guidance to reflect changes on the web since the publication of WCAG 2.0. The Working Group might also develop additional interim versions, continuing with WCAG 2.2, on a similar short timeline to provide additional support while the major version is completed.

## 1. Perceivable

Information and user interface components must be presentable to users in ways they can perceive.

### Guideline 1.1 Text Alternatives

Understanding Text Alternatives \| How to Meet Text Alternatives

Provide text alternatives for any non-text content so that it can be changed into other forms people need, such as large print, braille, speech, symbols or simpler language.

#### Success Criterion 1.1.1 Non-text Content

Understanding Non-text Content \| How to Meet Non-text Content

\(Level A\)

All non-text content that is presented to the user has a text alternative that serves the equivalent purpose, except for the situations listed below.

Controls, Input

If non-text content is a control or accepts user input, then it has a name that describes its purpose. \(Refer to Success Criterion 4.1.2 for additional requirements for controls and content that accepts user input.\)

Time-Based Media

If non-text content is time-based media, then text alternatives at least provide descriptive identification of the non-text content. \(Refer to Guideline 1.2 for additional requirements for media.\)

Test

If non-text content is a test or exercise that would be invalid if presented in text , then text alternatives at least provide descriptive identification of the non-text content.

Sensory

If non-text content is primarily intended to create a specific sensory experience , then text alternatives at least provide descriptive identification of the non-text content.

CAPTCHA

If the purpose of non-text content is to confirm that content is being accessed by a person rather than a computer, then text alternatives that identify and describe the purpose of the non-text content are provided, and alternative forms of CAPTCHA using output modes for different types of sensory perception are provided to accommodate different disabilities.

Decoration, Formatting, Invisible

If non-text content is pure decoration , is used only for visual formatting, or is not presented to users, then it is implemented in a way that it can be ignored by assistive technology .

### Guideline 1.2 Time-based Media

Understanding Time-based Media \| How to Meet Time-based Media

Provide alternatives for time-based media.

#### Success Criterion 1.2.1 Audio-only and Video-only \(Prerecorded\)

Understanding Audio-only and Video-only \(Prerecorded\) \| How to Meet Audio-only and Video-only \(Prerecorded\)

\(Level A\)

For prerecorded audio-only and prerecorded video-only media, the following are true, except when the audio or video is a media alternative for text and is clearly labeled as such:

Prerecorded Audio-only

An alternative for time-based media is provided that presents equivalent information for prerecorded audio-only content.

Prerecorded Video-only

Either an alternative for time-based media or an audio track is provided that presents equivalent information for prerecorded video-only content.

#### Success Criterion 1.2.2 Captions \(Prerecorded\)

Understanding Captions \(Prerecorded\) \| How to Meet Captions \(Prerecorded\)

\(Level A\)

Captions are provided for all prerecorded audio content in synchronized media , except when the media is a media alternative for text and is clearly labeled as such.

#### Success Criterion 1.2.3 Audio Description or Media Alternative \(Prerecorded\)

Understanding Audio Description or Media Alternative \(Prerecorded\) \| How to Meet Audio Description or Media Alternative \(Prerecorded\)

\(Level A\)

An alternative for time-based media or audio description of the prerecorded video content is provided for synchronized media , except when the media is a media alternative for text and is clearly labeled as such.

#### Success Criterion 1.2.4 Captions \(Live\)

Understanding Captions \(Live\) \| How to Meet Captions \(Live\)

\(Level AA\)

Captions are provided for all live audio content in synchronized media .

#### Success Criterion 1.2.5 Audio Description \(Prerecorded\)

Understanding Audio Description \(Prerecorded\) \| How to Meet Audio Description \(Prerecorded\)

\(Level AA\)

Audio description is provided for all prerecorded video content in synchronized media .

#### Success Criterion 1.2.6 Sign Language \(Prerecorded\)

Understanding Sign Language \(Prerecorded\) \| How to Meet Sign Language \(Prerecorded\)

\(Level AAA\)

Sign language interpretation is provided for all prerecorded audio content in synchronized media .

#### Success Criterion 1.2.7 Extended Audio Description \(Prerecorded\)

Understanding Extended Audio Description \(Prerecorded\) \| How to Meet Extended Audio Description \(Prerecorded\)

\(Level AAA\)

Where pauses in foreground audio are insufficient to allow audio descriptions to convey the sense of the video, extended audio description is provided for all prerecorded video content in synchronized media .

#### Success Criterion 1.2.8 Media Alternative \(Prerecorded\)

Understanding Media Alternative \(Prerecorded\) \| How to Meet Media Alternative \(Prerecorded\)

\(Level AAA\)

An alternative for time-based media is provided for all prerecorded synchronized media and for all prerecorded video-only media.

#### Success Criterion 1.2.9 Audio-only \(Live\)

Understanding Audio-only \(Live\) \| How to Meet Audio-only \(Live\)

\(Level AAA\)

An alternative for time-based media that presents equivalent information for live audio-only content is provided.

### Guideline 1.3 Adaptable

Understanding Adaptable \| How to Meet Adaptable

Create content that can be presented in different ways \(for example simpler layout\) without losing information or structure.

#### Success Criterion 1.3.1 Info and Relationships

Understanding Info and Relationships \| How to Meet Info and Relationships

\(Level A\)

Information, structure , and relationships conveyed through presentation can be programmatically determined or are available in text.

#### Success Criterion 1.3.2 Meaningful Sequence

Understanding Meaningful Sequence \| How to Meet Meaningful Sequence

\(Level A\)

When the sequence in which content is presented affects its meaning, a correct reading sequence can be programmatically determined .

#### Success Criterion 1.3.3 Sensory Characteristics

Understanding Sensory Characteristics \| How to Meet Sensory Characteristics

\(Level A\)

Instructions provided for understanding and operating content do not rely solely on sensory characteristics of components such as shape, color, size, visual location, orientation, or sound.

Note

For requirements related to color, refer to Guideline 1.4 .

#### Success Criterion 1.3.4 Orientation

Understanding Orientation \| How to Meet Orientation

\(Level AA\)

Content does not restrict its view and operation to a single display orientation, such as portrait or landscape, unless a specific display orientation is essential .

Note

Examples where a particular display orientation may be essential are a bank check, a piano application, slides for a projector or television, or virtual reality content where content is not necessarily restricted to landscape or portrait display orientation.

#### Success Criterion 1.3.5 Identify Input Purpose

Understanding Identify Input Purpose \| How to Meet Identify Input Purpose

\(Level AA\)

The purpose of each input field collecting information about the user can be programmatically determined when:

- The input field serves a purpose identified in the Input Purposes for user interface components section ; and
- The content is implemented using technologies with support for identifying the expected meaning for form input data.

#### Success Criterion 1.3.6 Identify Purpose

Understanding Identify Purpose \| How to Meet Identify Purpose

\(Level AAA\)

In content implemented using markup languages, the purpose of user interface components , icons, and regions can be programmatically determined .

### Guideline 1.4 Distinguishable

Understanding Distinguishable \| How to Meet Distinguishable

Make it easier for users to see and hear content including separating foreground from background.

#### Success Criterion 1.4.1 Use of Color

Understanding Use of Color \| How to Meet Use of Color

\(Level A\)

Color is not used as the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element.

Note

This success criterion addresses color perception specifically. Other forms of perception are covered in Guideline 1.3 including programmatic access to color and other visual presentation coding.

#### Success Criterion 1.4.2 Audio Control

Understanding Audio Control \| How to Meet Audio Control

\(Level A\)

If any audio on a web page plays automatically for more than 3 seconds, either a mechanism is available to pause or stop the audio, or a mechanism is available to control audio volume independently from the overall system volume level.

Note

Since any content that does not meet this success criterion can interfere with a user's ability to use the whole page, all content on the web page \(whether or not it is used to meet other success criteria\) must meet this success criterion. See Conformance Requirement 5: Non-Interference .

#### Success Criterion 1.4.3 Contrast \(Minimum\)

Understanding Contrast \(Minimum\) \| How to Meet Contrast \(Minimum\)

\(Level AA\)

The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for the following:

Large Text

Large-scale text and images of large-scale text have a contrast ratio of at least 3:1;

Incidental

Text or images of text that are part of an inactive user interface component , that are pure decoration , that are not visible to anyone, or that are part of a picture that contains significant other visual content, have no contrast requirement.

Logotypes

Text that is part of a logo or brand name has no contrast requirement.

#### Success Criterion 1.4.4 Resize Text

Understanding Resize Text \| How to Meet Resize Text

\(Level AA\)

Except for captions and images of text , text can be resized without assistive technology up to 200 percent without loss of content or functionality.

#### Success Criterion 1.4.5 Images of Text

Understanding Images of Text \| How to Meet Images of Text

\(Level AA\)

If the technologies being used can achieve the visual presentation, text is used to convey information rather than images of text except for the following:

Customizable

The image of text can be visually customized to the user's requirements;

Essential

A particular presentation of text is essential to the information being conveyed.

Note

Logotypes \(text that is part of a logo or brand name\) are considered essential.

#### Success Criterion 1.4.6 Contrast \(Enhanced\)

Understanding Contrast \(Enhanced\) \| How to Meet Contrast \(Enhanced\)

\(Level AAA\)

The visual presentation of text and images of text has a contrast ratio of at least 7:1, except for the following:

Large Text

Large-scale text and images of large-scale text have a contrast ratio of at least 4.5:1;

Incidental

Text or images of text that are part of an inactive user interface component , that are pure decoration , that are not visible to anyone, or that are part of a picture that contains significant other visual content, have no contrast requirement.

Logotypes

Text that is part of a logo or brand name has no contrast requirement.

#### Success Criterion 1.4.7 Low or No Background Audio

Understanding Low or No Background Audio \| How to Meet Low or No Background Audio

\(Level AAA\)

For prerecorded audio-only content that \(1\) contains primarily speech in the foreground, \(2\) is not an audio CAPTCHA or audio logo, and \(3\) is not vocalization intended to be primarily musical expression such as singing or rapping, at least one of the following is true:

No Background

The audio does not contain background sounds.

Turn Off

The background sounds can be turned off.

20 dB

The background sounds are at least 20 decibels lower than the foreground speech content, with the exception of occasional sounds that last for only one or two seconds.

Note

Per the definition of "decibel," background sound that meets this requirement will be approximately four times quieter than the foreground speech content.

#### Success Criterion 1.4.8 Visual Presentation

Understanding Visual Presentation \| How to Meet Visual Presentation

\(Level AAA\)

For the visual presentation of blocks of text , a mechanism is available to achieve the following:

- Foreground and background colors can be selected by the user.
- Width is no more than 80 characters or glyphs \(40 if CJK\).
- Text is not justified \(aligned to both the left and the right margins\).
- Line spacing \(leading\) is at least space-and-a-half within paragraphs, and paragraph spacing is at least 1.5 times larger than the line spacing.
- Text can be resized without assistive technology up to 200 percent in a way that does not require the user to scroll horizontally to read a line of text on a full-screen window .

Note 1

Content is not required to use these values. The requirement is that a mechanism is available for users to change these presentation aspects. The mechanism can be provided by the browser or other user agent. Content is not required to provide the mechanism.

Note 2

Writing systems for some languages use different presentation aspects to improve readability and legibility. If a presentation aspect in this success criterion is not used in a writing system, content in that writing system does not need to use that presentation setting and can conform without it. Authors are encouraged to follow guidance for improving readability and legibility of text in their writing system.

#### Success Criterion 1.4.9 Images of Text \(No Exception\)

Understanding Images of Text \(No Exception\) \| How to Meet Images of Text \(No Exception\)

\(Level AAA\)

Images of text are only used for pure decoration or where a particular presentation of text is essential to the information being conveyed.

Note

Logotypes \(text that is part of a logo or brand name\) are considered essential.

#### Success Criterion 1.4.10 Reflow

Understanding Reflow \| How to Meet Reflow

\(Level AA\)

Content can be presented without loss of information or functionality, and without requiring scrolling in two dimensions for:

- Vertical scrolling content at a width equivalent to 320 CSS pixels ;
- Horizontal scrolling content at a height equivalent to 256 CSS pixels .

Except for parts of the content which require two-dimensional layout for usage or meaning.

Note 1

320 CSS pixels is equivalent to a starting viewport width of 1280 CSS pixels wide at 400% zoom. For web content which is designed to scroll horizontally \(e.g., with vertical text\), 256 CSS pixels is equivalent to a starting viewport height of 1024 CSS pixels at 400% zoom.

Note 2

Examples of content which requires two-dimensional layout are images required for understanding \(such as maps and diagrams\), video, games, presentations, data tables \(not individual cells\), and interfaces where it is necessary to keep toolbars in view while manipulating content. It is acceptable to provide two-dimensional scrolling for such parts of the content.

#### Success Criterion 1.4.11 Non-text Contrast

Understanding Non-text Contrast \| How to Meet Non-text Contrast

\(Level AA\)

The visual presentation of the following have a contrast ratio of at least 3:1 against adjacent color\(s\):

User Interface Components Visual information required to identify user interface components and states , except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author; Graphical Objects Parts of graphics required to understand the content, except when a particular presentation of graphics is essential to the information being conveyed.

#### Success Criterion 1.4.12 Text Spacing

Understanding Text Spacing \| How to Meet Text Spacing

\(Level AA\)

In content implemented using markup languages that support the following text style properties , no loss of content or functionality occurs by setting all of the following and by changing no other style property:

- Line height \(line spacing\) to at least 1.5 times the font size;
- Spacing following paragraphs to at least 2 times the font size;
- Letter spacing \(tracking\) to at least 0.12 times the font size;
- Word spacing to at least 0.16 times the font size.

Exception: Human languages and scripts that do not make use of one or more of these text style properties in written text can conform using only the properties that exist for that combination of language and script.

Note 1

Content is not required to use these text spacing values. The requirement is to ensure that when a user overrides the authored text spacing, content or functionality is not lost.

Note 2

Writing systems for some languages use different text spacing settings, such as paragraph start indent. Authors are encouraged to follow locally available guidance for improving readability and legibility of text in their writing system.

#### Success Criterion 1.4.13 Content on Hover or Focus

Understanding Content on Hover or Focus \| How to Meet Content on Hover or Focus

\(Level AA\)

Where receiving and then removing pointer hover or keyboard focus triggers additional content to become visible and then hidden, the following are true:

Dismissible A mechanism is available to dismiss the additional content without moving pointer hover or keyboard focus, unless the additional content communicates an input error or does not obscure or replace other content; Hoverable If pointer hover can trigger the additional content, then the pointer can be moved over the additional content without the additional content disappearing; Persistent The additional content remains visible until the hover or focus trigger is removed, the user dismisses it, or its information is no longer valid.

Exception: The visual presentation of the additional content is controlled by the user agent and is not modified by the author.

Note 1

Examples of additional content controlled by the user agent include browser tooltips created through use of the HTML title attribute \[ HTML \].

Note 2

Custom tooltips, sub-menus, and other nonmodal popups that display on hover and focus are examples of additional content covered by this criterion.

Note 3

This criterion applies to content that appears in addition to the triggering component itself. Since hidden components that are made visible on keyboard focus \(such as links used to skip to another part of a page\) do not present additional content they are not covered by this criterion.

## 2. Operable

User interface components and navigation must be operable.

### Guideline 2.1 Keyboard Accessible

Understanding Keyboard Accessible \| How to Meet Keyboard Accessible

Make all functionality available from a keyboard.

#### Success Criterion 2.1.1 Keyboard

Understanding Keyboard \| How to Meet Keyboard

\(Level A\)

All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement and not just the endpoints.

Note 1

This exception relates to the underlying function, not the input technique. For example, if using handwriting to enter text, the input technique \(handwriting\) requires path-dependent input but the underlying function \(text input\) does not.

Note 2

This does not forbid and should not discourage providing mouse input or other input methods in addition to keyboard operation.

#### Success Criterion 2.1.2 No Keyboard Trap

Understanding No Keyboard Trap \| How to Meet No Keyboard Trap

\(Level A\)

If keyboard focus can be moved to a component of the page using a keyboard interface , then focus can be moved away from that component using only a keyboard interface, and, if it requires more than unmodified arrow or tab keys or other standard exit methods, the user is advised of the method for moving focus away.

Note

Since any content that does not meet this success criterion can interfere with a user's ability to use the whole page, all content on the web page \(whether it is used to meet other success criteria or not\) must meet this success criterion. See Conformance Requirement 5: Non-Interference .

#### Success Criterion 2.1.3 Keyboard \(No Exception\)

Understanding Keyboard \(No Exception\) \| How to Meet Keyboard \(No Exception\)

\(Level AAA\)

All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes.

#### Success Criterion 2.1.4 Character Key Shortcuts

Understanding Character Key Shortcuts \| How to Meet Character Key Shortcuts

\(Level A\)

If a keyboard shortcut is implemented in content using only letter \(including upper- and lower-case letters\), punctuation, number, or symbol characters, then at least one of the following is true:

Turn off A mechanism is available to turn the shortcut off; Remap A mechanism is available to remap the shortcut to include one or more non-printable keyboard keys \(e.g., Ctrl, Alt\); Active only on focus The keyboard shortcut for a user interface component is only active when that component has focus.

### Guideline 2.2 Enough Time

Understanding Enough Time \| How to Meet Enough Time

Provide users enough time to read and use content.

#### Success Criterion 2.2.1 Timing Adjustable

Understanding Timing Adjustable \| How to Meet Timing Adjustable

\(Level A\)

For each time limit that is set by the content, at least one of the following is true:

Turn off

The user is allowed to turn off the time limit before encountering it; or

Adjust

The user is allowed to adjust the time limit before encountering it over a wide range that is at least ten times the length of the default setting; or

Extend

The user is warned before time expires and given at least 20 seconds to extend the time limit with a simple action \(for example, "press the space bar"\), and the user is allowed to extend the time limit at least ten times; or

Real-time Exception

The time limit is a required part of a real-time event \(for example, an auction\), and no alternative to the time limit is possible; or

Essential Exception

The time limit is essential and extending it would invalidate the activity; or

20 Hour Exception

The time limit is longer than 20 hours.

Note

This success criterion helps ensure that users can complete tasks without unexpected changes in content or context that are a result of a time limit. This success criterion should be considered in conjunction with Success Criterion 3.2.1 , which puts limits on changes of content or context as a result of user action.

#### Success Criterion 2.2.2 Pause, Stop, Hide

Understanding Pause, Stop, Hide \| How to Meet Pause, Stop, Hide

\(Level A\)

For moving, blinking , scrolling, or auto-updating information, all of the following are true:

Moving, blinking, scrolling

For any moving, blinking or scrolling information that \(1\) starts automatically, \(2\) lasts more than five seconds, and \(3\) is presented in parallel with other content, there is a mechanism for the user to pause , stop, or hide it unless the movement, blinking, or scrolling is part of an activity where it is essential ; and

Auto-updating

For any auto-updating information that \(1\) starts automatically and \(2\) is presented in parallel with other content, there is a mechanism for the user to pause, stop, or hide it or to control the frequency of the update unless the auto-updating is part of an activity where it is essential.

Note 1

For requirements related to flickering or flashing content, refer to Guideline 2.3 .

Note 2

Since any content that does not meet this success criterion can interfere with a user's ability to use the whole page, all content on the web page \(whether it is used to meet other success criteria or not\) must meet this success criterion. See Conformance Requirement 5: Non-Interference .

Note 3

Content that is updated periodically by software or that is streamed to the user agent is not required to preserve or present information that is generated or received between the initiation of the pause and resuming presentation, as this may not be technically possible, and in many situations could be misleading to do so.

Note 4

An animation that occurs as part of a preload phase or similar situation can be considered essential if interaction cannot occur during that phase for all users and if not indicating progress could confuse users or cause them to think that content was frozen or broken.

#### Success Criterion 2.2.3 No Timing

Understanding No Timing \| How to Meet No Timing

\(Level AAA\)

Timing is not an essential part of the event or activity presented by the content, except for non-interactive synchronized media and real-time events .

#### Success Criterion 2.2.4 Interruptions

Understanding Interruptions \| How to Meet Interruptions

\(Level AAA\)

Interruptions can be postponed or suppressed by the user, except interruptions involving an emergency .

#### Success Criterion 2.2.5 Re-authenticating

Understanding Re-authenticating \| How to Meet Re-authenticating

\(Level AAA\)

When an authenticated session expires, the user can continue the activity without loss of data after re-authenticating.

#### Success Criterion 2.2.6 Timeouts

Understanding Timeouts \| How to Meet Timeouts

\(Level AAA\)

Users are warned of the duration of any user inactivity that could cause data loss, unless the data is preserved for more than 20 hours when the user does not take any actions.

Note

Privacy regulations may require explicit user consent before user identification has been authenticated and before user data is preserved. In cases where the user is a minor, explicit consent may not be solicited in most jurisdictions, countries or regions. Consultation with privacy professionals and legal counsel is advised when considering data preservation as an approach to satisfy this success criterion.

### Guideline 2.3 Seizures and Physical Reactions

Understanding Seizures and Physical Reactions \| How to Meet Seizures and Physical Reactions

Do not design content in a way that is known to cause seizures or physical reactions.

#### Success Criterion 2.3.1 Three Flashes or Below Threshold

Understanding Three Flashes or Below Threshold \| How to Meet Three Flashes or Below Threshold

\(Level A\)

Web pages do not contain anything that flashes more than three times in any one second period, or the flash is below the general flash and red flash thresholds .

Note

Since any content that does not meet this success criterion can interfere with a user's ability to use the whole page, all content on the web page \(whether it is used to meet other success criteria or not\) must meet this success criterion. See Conformance Requirement 5: Non-Interference .

#### Success Criterion 2.3.2 Three Flashes

Understanding Three Flashes \| How to Meet Three Flashes

\(Level AAA\)

Web pages do not contain anything that flashes more than three times in any one second period.

#### Success Criterion 2.3.3 Animation from Interactions

Understanding Animation from Interactions \| How to Meet Animation from Interactions

\(Level AAA\)

Motion animation triggered by interaction can be disabled, unless the animation is essential to the functionality or the information being conveyed.

### Guideline 2.4 Navigable

Understanding Navigable \| How to Meet Navigable

Provide ways to help users navigate, find content, and determine where they are.

#### Success Criterion 2.4.1 Bypass Blocks

Understanding Bypass Blocks \| How to Meet Bypass Blocks

\(Level A\)

A mechanism is available to bypass blocks of content that are repeated on multiple web pages .

#### Success Criterion 2.4.2 Page Titled

Understanding Page Titled \| How to Meet Page Titled

\(Level A\)

Web pages have titles that describe topic or purpose.

#### Success Criterion 2.4.3 Focus Order

Understanding Focus Order \| How to Meet Focus Order

\(Level A\)

If a web page can be navigated sequentially and the navigation sequences affect meaning or operation, focusable components receive focus in an order that preserves meaning and operability.

#### Success Criterion 2.4.4 Link Purpose \(In Context\)

Understanding Link Purpose \(In Context\) \| How to Meet Link Purpose \(In Context\)

\(Level A\)

The purpose of each link can be determined from the link text alone or from the link text together with its programmatically determined link context , except where the purpose of the link would be ambiguous to users in general .

#### Success Criterion 2.4.5 Multiple Ways

Understanding Multiple Ways \| How to Meet Multiple Ways

\(Level AA\)

More than one way is available to locate a web page within a set of web pages except where the web page is the result of, or a step in, a process .

#### Success Criterion 2.4.6 Headings and Labels

Understanding Headings and Labels \| How to Meet Headings and Labels

\(Level AA\)

Headings and labels describe topic or purpose.

#### Success Criterion 2.4.7 Focus Visible

Understanding Focus Visible \| How to Meet Focus Visible

\(Level AA\)

Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible.

#### Success Criterion 2.4.8 Location

Understanding Location \| How to Meet Location

\(Level AAA\)

Information about the user's location within a set of web pages is available.

#### Success Criterion 2.4.9 Link Purpose \(Link Only\)

Understanding Link Purpose \(Link Only\) \| How to Meet Link Purpose \(Link Only\)

\(Level AAA\)

A mechanism is available to allow the purpose of each link to be identified from link text alone, except where the purpose of the link would be ambiguous to users in general .

#### Success Criterion 2.4.10 Section Headings

Understanding Section Headings \| How to Meet Section Headings

\(Level AAA\)

Section headings are used to organize the content.

Note 1

"Heading" is used in its general sense and includes titles and other ways to add a heading to different types of content.

Note 2

This success criterion covers sections within writing, not user interface components . User interface components are covered under Success Criterion 4.1.2 .

#### Success Criterion 2.4.11 Focus Not Obscured \(Minimum\)

Understanding Focus Not Obscured \(Minimum\) \| How to Meet Focus Not Obscured \(Minimum\)

\(Level AA\)

New

When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content.

Note 1

Where content in a configurable interface can be repositioned by the user, then only the initial positions of user-movable content are considered for testing and conformance of this success criterion.

Note 2

Content opened by the user may obscure the component receiving focus. If the user can reveal the focused component without advancing the keyboard focus, the component with focus is not considered visually hidden due to author-created content.

#### Success Criterion 2.4.12 Focus Not Obscured \(Enhanced\)

Understanding Focus Not Obscured \(Enhanced\) \| How to Meet Focus Not Obscured \(Enhanced\)

\(Level AAA\)

New

When a user interface component receives keyboard focus, no part of the component is hidden by author-created content.

#### Success Criterion 2.4.13 Focus Appearance

Understanding Focus Appearance \| How to Meet Focus Appearance

\(Level AAA\)

New

When the keyboard focus indicator is visible, an area of the focus indicator meets all the following:

- is at least as large as the area of a 2 CSS pixel thick perimeter of the unfocused component or sub-component, and
- has a contrast ratio of at least 3:1 between the same pixels in the focused and unfocused states.

Exceptions:

- The focus indicator is determined by the user agent and cannot be adjusted by the author, or
- The focus indicator and the indicator's background color are not modified by the author.

Note 1

What is perceived as the user interface component or sub-component \(to determine the perimeter\) depends on its visual presentation . The visual presentation includes the component's visible content , border, and component-specific background. It does not include shadow and glow effects outside the component's content, background, or border.

Note 2

Examples of sub-components that may receive a focus indicator are menu items in an opened drop-down menu, or focusable cells in a grid.

Note 3

Contrast calculations can be based on colors defined within the technology \(such as HTML , CSS, and SVG\). Pixels modified by user agent resolution enhancements and anti-aliasing can be ignored.

### Guideline 2.5 Input Modalities

Understanding Input Modalities \| How to Meet Input Modalities

Make it easier for users to operate functionality through various inputs beyond keyboard.

#### Success Criterion 2.5.1 Pointer Gestures

Understanding Pointer Gestures \| How to Meet Pointer Gestures

\(Level A\)

All functionality that uses multipoint or path-based gestures for operation can be operated with a single pointer without a path-based gesture, unless a multipoint or path-based gesture is essential .

Note

This requirement applies to web content that interprets pointer actions \(i.e., this does not apply to actions that are required to operate the user agent or assistive technology\).

#### Success Criterion 2.5.2 Pointer Cancellation

Understanding Pointer Cancellation \| How to Meet Pointer Cancellation

\(Level A\)

For functionality that can be operated using a single pointer , at least one of the following is true:

No Down-Event The down-event of the pointer is not used to execute any part of the function; Abort or Undo Completion of the function is on the up-event , and a mechanism is available to abort the function before completion or to undo the function after completion; Up Reversal The up-event reverses any outcome of the preceding down-event; Essential Completing the function on the down-event is essential .

Note 1

Functions that emulate a keyboard or numeric keypad key press are considered essential.

Note 2

This requirement applies to web content that interprets pointer actions \(i.e., this does not apply to actions that are required to operate the user agent or assistive technology\).

#### Success Criterion 2.5.3 Label in Name

Understanding Label in Name \| How to Meet Label in Name

\(Level A\)

For user interface components with labels that include text or images of text , the name contains the text that is presented visually.

Note

A best practice is to have the text of the label at the start of the name.

#### Success Criterion 2.5.4 Motion Actuation

Understanding Motion Actuation \| How to Meet Motion Actuation

\(Level A\)

Functionality that can be operated by device motion or user motion can also be operated by user interface components and responding to the motion can be disabled to prevent accidental actuation, except when:

Supported Interface The motion is used to operate functionality through an accessibility supported interface; Essential The motion is essential for the function and doing so would invalidate the activity.

#### Success Criterion 2.5.5 Target Size \(Enhanced\)

Understanding Target Size \(Enhanced\) \| How to Meet Target Size \(Enhanced\)

\(Level AAA\)

The size of the target for pointer inputs is at least 44 by 44 CSS pixels except when:

Equivalent The target is available through an equivalent link or control on the same page that is at least 44 by 44 CSS pixels; Inline The target is in a sentence or block of text ; User Agent Control The size of the target is determined by the user agent and is not modified by the author; Essential A particular presentation of the target is essential to the information being conveyed.

#### Success Criterion 2.5.6 Concurrent Input Mechanisms

Understanding Concurrent Input Mechanisms \| How to Meet Concurrent Input Mechanisms

\(Level AAA\)

Web content does not restrict use of input modalities available on a platform except where the restriction is essential , required to ensure the security of the content, or required to respect user settings.

#### Success Criterion 2.5.7 Dragging Movements

Understanding Dragging Movements \| How to Meet Dragging Movements

\(Level AA\)

New

All functionality that uses a dragging movement for operation can be achieved by a single pointer without dragging, unless dragging is essential or the functionality is determined by the user agent and not modified by the author.

Note

This requirement applies to web content that interprets pointer actions \(i.e., this does not apply to actions that are required to operate the user agent or assistive technology\).

#### Success Criterion 2.5.8 Target Size \(Minimum\)

Understanding Target Size \(Minimum\) \| How to Meet Target Size \(Minimum\)

\(Level AA\)

New

The size of the target for pointer inputs is at least 24 by 24 CSS pixels , except when:

Spacing Undersized targets \(those less than 24 by 24 CSS pixels\) are positioned so that if a 24 CSS pixel diameter circle is centered on the bounding box of each, the circles do not intersect another target or the circle for another undersized target; Equivalent The function can be achieved through a different control on the same page that meets this criterion; Inline The target is in a sentence or its size is otherwise constrained by the line-height of non-target text; User Agent Control The size of the target is determined by the user agent and is not modified by the author; Essential A particular presentation of the target is essential or is legally required for the information being conveyed.

Note 1

Targets that allow for values to be selected spatially based on position within the target are considered one target for the purpose of the success criterion. Examples include sliders, color pickers displaying a gradient of colors, or editable areas where you position the cursor.

Note 2

For inline targets the line-height should be interpreted as perpendicular to the flow of text. For example, in a language displayed vertically, the line-height would be horizontal.

## 3. Understandable

Information and the operation of the user interface must be understandable.

### Guideline 3.1 Readable

Understanding Readable \| How to Meet Readable

Make text content readable and understandable.

#### Success Criterion 3.1.1 Language of Page

Understanding Language of Page \| How to Meet Language of Page

\(Level A\)

The default human language of each web page can be programmatically determined .

#### Success Criterion 3.1.2 Language of Parts

Understanding Language of Parts \| How to Meet Language of Parts

\(Level AA\)

The human language of each passage or phrase in the content can be programmatically determined except for proper names, technical terms, words of indeterminate language, and words or phrases that have become part of the vernacular of the immediately surrounding text .

#### Success Criterion 3.1.3 Unusual Words

Understanding Unusual Words \| How to Meet Unusual Words

\(Level AAA\)

A mechanism is available for identifying specific definitions of words or phrases used in an unusual or restricted way , including idioms and jargon .

#### Success Criterion 3.1.4 Abbreviations

Understanding Abbreviations \| How to Meet Abbreviations

\(Level AAA\)

A mechanism for identifying the expanded form or meaning of abbreviations is available.

#### Success Criterion 3.1.5 Reading Level

Understanding Reading Level \| How to Meet Reading Level

\(Level AAA\)

When text requires reading ability more advanced than the lower secondary education level after removal of proper names and titles, supplemental content , or a version that does not require reading ability more advanced than the lower secondary education level, is available.

#### Success Criterion 3.1.6 Pronunciation

Understanding Pronunciation \| How to Meet Pronunciation

\(Level AAA\)

A mechanism is available for identifying specific pronunciation of words where meaning of the words, in context, is ambiguous without knowing the pronunciation.

### Guideline 3.2 Predictable

Understanding Predictable \| How to Meet Predictable

Make web pages appear and operate in predictable ways.

#### Success Criterion 3.2.1 On Focus

Understanding On Focus \| How to Meet On Focus

\(Level A\)

When any user interface component receives focus, it does not initiate a change of context .

#### Success Criterion 3.2.2 On Input

Understanding On Input \| How to Meet On Input

\(Level A\)

Changing the setting of any user interface component does not automatically cause a change of context unless the user has been advised of the behavior before using the component.

#### Success Criterion 3.2.3 Consistent Navigation

Understanding Consistent Navigation \| How to Meet Consistent Navigation

\(Level AA\)

Navigational mechanisms that are repeated on multiple web pages within a set of web pages occur in the same relative order each time they are repeated, unless a change is initiated by the user.

#### Success Criterion 3.2.4 Consistent Identification

Understanding Consistent Identification \| How to Meet Consistent Identification

\(Level AA\)

Components that have the same functionality within a set of web pages are identified consistently.

#### Success Criterion 3.2.5 Change on Request

Understanding Change on Request \| How to Meet Change on Request

\(Level AAA\)

Changes of context are initiated only by user request or a mechanism is available to turn off such changes.

#### Success Criterion 3.2.6 Consistent Help

Understanding Consistent Help \| How to Meet Consistent Help

\(Level A\)

New

If a web page contains any of the following help mechanisms , and those mechanisms are repeated on multiple web pages within a set of web pages , they occur in the same order relative to other page content, unless a change is initiated by the user:

- Human contact details;
- Human contact mechanism;
- Self-help option;
- A fully automated contact mechanism.

Note 1

Help mechanisms may be provided directly on the page, or may be provided via a direct link to a different page containing the information.

Note 2

For this success criterion, "the same order relative to other page content" can be thought of as how the content is ordered when the page is serialized. The visual position of a help mechanism is likely to be consistent across pages for the same page variation \(e.g., CSS break-point\). The user can initiate a change, such as changing the page's zoom or orientation, which may trigger a different page variation. This criterion is concerned with relative order across pages displayed in the same page variation \(e.g., same zoom level and orientation\).

### Guideline 3.3 Input Assistance

Understanding Input Assistance \| How to Meet Input Assistance

Help users avoid and correct mistakes.

#### Success Criterion 3.3.1 Error Identification

Understanding Error Identification \| How to Meet Error Identification

\(Level A\)

If an input error is automatically detected, the item that is in error is identified and the error is described to the user in text.

#### Success Criterion 3.3.2 Labels or Instructions

Understanding Labels or Instructions \| How to Meet Labels or Instructions

\(Level A\)

Labels or instructions are provided when content requires user input.

#### Success Criterion 3.3.3 Error Suggestion

Understanding Error Suggestion \| How to Meet Error Suggestion

\(Level AA\)

If an input error is automatically detected and suggestions for correction are known, then the suggestions are provided to the user, unless it would jeopardize the security or purpose of the content.

#### Success Criterion 3.3.4 Error Prevention \(Legal, Financial, Data\)

Understanding Error Prevention \(Legal, Financial, Data\) \| How to Meet Error Prevention \(Legal, Financial, Data\)

\(Level AA\)

For web pages that cause legal commitments or financial transactions for the user to occur, that modify or delete user-controllable data in data storage systems, or that submit user test responses, at least one of the following is true:

Reversible Submissions are reversible. Checked Data entered by the user is checked for input errors and the user is provided an opportunity to correct them. Confirmed A mechanism is available for reviewing, confirming, and correcting information before finalizing the submission.

#### Success Criterion 3.3.5 Help

Understanding Help \| How to Meet Help

\(Level AAA\)

Context-sensitive help is available.

#### Success Criterion 3.3.6 Error Prevention \(All\)

Understanding Error Prevention \(All\) \| How to Meet Error Prevention \(All\)

\(Level AAA\)

For web pages that require the user to submit information, at least one of the following is true:

Reversible Submissions are reversible. Checked Data entered by the user is checked for input errors and the user is provided an opportunity to correct them. Confirmed A mechanism is available for reviewing, confirming, and correcting information before finalizing the submission.

#### Success Criterion 3.3.7 Redundant Entry

Understanding Redundant Entry \| How to Meet Redundant Entry

\(Level A\)

New

Information previously entered by or provided to the user that is required to be entered again in the same process is either:

- auto-populated, or
- available for the user to select.

Except when:

- re-entering the information is essential ,
- the information is required to ensure the security of the content, or
- previously entered information is no longer valid.

#### Success Criterion 3.3.8 Accessible Authentication \(Minimum\)

Understanding Accessible Authentication \(Minimum\) \| How to Meet Accessible Authentication \(Minimum\)

\(Level AA\)

New

A cognitive function test \(such as remembering a password or solving a puzzle\) is not required for any step in an authentication process unless that step provides at least one of the following:

Alternative Another authentication method that does not rely on a cognitive function test. Mechanism A mechanism is available to assist the user in completing the cognitive function test. Object Recognition The cognitive function test is to recognize objects. Personal Content The cognitive function test is to identify non-text content the user provided to the website.

Note 1

"Object recognition" and "Personal content" may be represented by images, video, or audio.

Note 2

Examples of mechanisms that satisfy this criterion include:

- support for password entry by password managers to reduce memory need, and
- copy and paste to reduce the cognitive burden of re-typing.

#### Success Criterion 3.3.9 Accessible Authentication \(Enhanced\)

Understanding Accessible Authentication \(Enhanced\) \| How to Meet Accessible Authentication \(Enhanced\)

\(Level AAA\)

New

A cognitive function test \(such as remembering a password or solving a puzzle\) is not required for any step in an authentication process unless that step provides at least one of the following:

Alternative Another authentication method that does not rely on a cognitive function test. Mechanism A mechanism is available to assist the user in completing the cognitive function test.

## 4. Robust

Content must be robust enough that it can be interpreted by a wide variety of user agents, including assistive technologies.

### Guideline 4.1 Compatible

Understanding Compatible \| How to Meet Compatible

Maximize compatibility with current and future user agents, including assistive technologies.

#### Success Criterion 4.1.1 Parsing \(Obsolete and removed\)

Understanding Parsing \(Obsolete and removed\) \| How to Meet Parsing \(Obsolete and removed\)

Note

This criterion was originally adopted to address problems that assistive technology had directly parsing HTML . Assistive technology no longer has any need to directly parse HTML . Consequently, these problems either no longer exist or are addressed by other criteria. This criterion no longer has utility and is removed.

#### Success Criterion 4.1.2 Name, Role, Value

Understanding Name, Role, Value \| How to Meet Name, Role, Value

\(Level A\)

For all user interface components \(including but not limited to: form elements, links and components generated by scripts\), the name and role can be programmatically determined ; states , properties, and values that can be set by the user can be programmatically set ; and notification of changes to these items is available to user agents , including assistive technologies .

Note

This success criterion is primarily for web authors who develop or script their own user interface components. For example, standard HTML controls already meet this success criterion when used according to specification.

#### Success Criterion 4.1.3 Status Messages

Understanding Status Messages \| How to Meet Status Messages

\(Level AA\)

In content implemented using markup languages, status messages can be programmatically determined through role or properties such that they can be presented to the user by assistive technologies without receiving focus.

## 5. Conformance

This section lists requirements for conformance to WCAG 2.2. It also gives information about how to make conformance claims, which are optional. Finally, it describes what it means to be accessibility supported , since only accessibility-supported ways of using technologies can be relied upon for conformance. Understanding Conformance includes further explanation of the accessibility-supported concept.

### 5.1 Interpreting Normative Requirements

The main content of WCAG 2.2 is normative and defines requirements that impact conformance claims. Introductory material, appendices, sections marked as "non-normative", diagrams, examples, and notes are informative \(non-normative\). Non-normative material provides advisory information to help interpret the guidelines but does not create requirements that impact a conformance claim.

The key words MAY , MUST , MUST NOT , NOT RECOMMENDED , RECOMMENDED , SHOULD , and SHOULD NOT are to be interpreted as described in \[ RFC2119 \].

### 5.2 Conformance Requirements

In order for a web page to conform to WCAG 2.2, all of the following conformance requirements must be satisfied:

#### 5.2.1 Conformance Level

One of the following levels of conformance is met in full.

- For Level A conformance \(the minimum level of conformance\), the web page satisfies all the Level A success criteria, or a conforming alternate version is provided.
- For Level AA conformance, the web page satisfies all the Level A and Level AA success criteria, or a Level AA conforming alternate version is provided.
- For Level AAA conformance, the web page satisfies all the Level A, Level AA and Level AAA success criteria, or a Level AAA conforming alternate version is provided.

Note 1

Although conformance can only be achieved at the stated levels, authors are encouraged to report \(in their claim\) any progress toward meeting success criteria from all levels beyond the achieved level of conformance.

Note 2

It is not recommended that Level AAA conformance be required as a general policy for entire sites because it is not possible to satisfy all Level AAA success criteria for some content.

#### 5.2.2 Full pages

Conformance \(and conformance level\) is for full web page\(s\) only, and cannot be achieved if part of a web page is excluded.

Note 1

For the purpose of determining conformance, alternatives to part of a page's content are considered part of the page when the alternatives can be obtained directly from the page, e.g., a long description or an alternative presentation of a video.

Note 2

Authors of web pages that cannot conform due to content outside of the author's control may consider a Statement of Partial Conformance .

Note 3

A full page includes each variation of the page that is automatically presented by the page for various screen sizes \(e.g. variations in a responsive web page\). Each of these variations needs to conform \(or needs to have a conforming alternate version\) in order for the entire page to conform.

#### 5.2.3 Complete processes

When a web page is one of a series of web pages presenting a process \(i.e., a sequence of steps that need to be completed in order to accomplish an activity\), all web pages in the process conform at the specified level or better. \(Conformance is not possible at a particular level if any page in the process does not conform at that level or better.\)

Example

An online store has a series of pages that are used to select and purchase products. All pages in the series from start to finish \(checkout\) conform in order for any page that is part of the process to conform.

#### 5.2.4 Only Accessibility-Supported Ways of Using Technologies

Only accessibility-supported ways of using technologies are relied upon to satisfy the success criteria. Any information or functionality that is provided in a way that is not accessibility supported is also available in a way that is accessibility supported. \(See Understanding accessibility support .\)

#### 5.2.5 Non-Interference

If technologies are used in a way that is not accessibility supported , or if they are used in a non-conforming way, then they do not block the ability of users to access the rest of the page. In addition, the web page as a whole continues to meet the conformance requirements under each of the following conditions:

- when any technology that is not relied upon is turned on in a user agent,
- when any technology that is not relied upon is turned off in a user agent, and
- when any technology that is not relied upon is not supported by a user agent

In addition, the following success criteria apply to all content on the page, including content that is not otherwise relied upon to meet conformance, because failure to meet them could interfere with any use of the page:

- 1.4.2 - Audio Control ,
- 2.1.2 - No Keyboard Trap ,
- 2.3.1 - Three Flashes or Below Threshold , and
- 2.2.2 - Pause, Stop, Hide .

Note

If a page cannot conform \(for example, a conformance test page or an example page\), it cannot be included in the scope of conformance or in a conformance claim.

For more information, including examples, see Understanding Conformance Requirements .

### 5.3 Conformance Claims \(Optional\)

Conformance is defined only for web pages . However, a conformance claim may be made to cover one page, a series of pages, or multiple related web pages.

#### 5.3.1 Required Components of a Conformance Claim

Conformance claims are not required . Authors can conform to WCAG 2.2 without making a claim. However, if a conformance claim is made, then the conformance claim must include the following information:

- Date of the claim
- Guidelines title, version and URI "Web Content Accessibility Guidelines 2.2 at https://www.w3.org/TR/WCAG22/ "
- Conformance level satisfied: \(Level A, AA or AAA\)

A concise description of the web pages , such as a list of URIs for which the claim is made, including whether subdomains are included in the claim.

Note 1

The web pages may be described by list or by an expression that describes all of the URIs included in the claim.

Note 2

Web-based products that do not have a URI prior to installation on the customer's website may have a statement that the product would conform when installed.

- A list of the web content technologies relied upon .

Note 3

If a conformance logo is used, it would constitute a claim and must be accompanied by the required components of a conformance claim listed above.

#### 5.3.2 Optional Components of a Conformance Claim

In addition to the required components of a conformance claim above, consider providing additional information to assist users. Recommended additional information includes:

- A list of success criteria beyond the level of conformance claimed that have been met. This information should be provided in a form that users can use, preferably machine-readable metadata.
- A list of the specific technologies that are " used but not relied upon ."
- A list of user agents, including assistive technologies that were used to test the content.
- A list of specific accessibility characteristics of the content, provided in machine-readable metadata.
- Information about any additional steps taken that go beyond the success criteria to enhance accessibility.
- A machine-readable metadata version of the list of specific technologies that are relied upon .
- A machine-readable metadata version of the conformance claim.

Note 1

Refer to Understanding Conformance Claims for more information and example conformance claims.

Note 2

Refer to Understanding Metadata for more information about the use of metadata in conformance claims.

### 5.4 Statement of Partial Conformance - Third Party Content

Web pages that will later have additional content added can use a 'statement of partial conformance'. For example, an email program, a blog, an article that allows users to add comments, or applications supporting user-contributed content. Another example would be a page, such as a portal or news site, composed of content aggregated from multiple contributors, or sites that automatically insert content from other sources over time, such as when advertisements are inserted dynamically.

In these cases, it is not possible to know at the time of original posting what the uncontrolled content of the pages will be. It is important to note that the uncontrolled content can affect the accessibility of the controlled content as well. Two options are available:

A determination of conformance can be made based on best knowledge. If a page of this type is monitored and repaired \(non-conforming content is removed or brought into conformance\) within two business days, then a determination or claim of conformance can be made since, except for errors in externally contributed content which are corrected or removed when encountered, the page conforms. No conformance claim can be made if it is not possible to monitor or correct non-conforming content;

OR

A "statement of partial conformance" may be made that the page does not conform, but could conform if certain parts were removed. The form of that statement would be, "This page does not conform, but would conform to WCAG 2.2 at level X if the following parts from uncontrolled sources were removed." In addition, the following would also be true of uncontrolled content that is described in the statement of partial conformance:

- It is not content that is under the author's control.
- It is described in a way that users can identify \(e.g., they cannot be described as "all parts that we do not control" unless they are clearly marked as such.\)

### 5.5 Statement of Partial Conformance - Language

A "statement of partial conformance due to language" may be made when the page does not conform, but would conform if accessibility support existed for \(all of\) the language\(s\) used on the page. The form of that statement would be, "This page does not conform, but would conform to WCAG 2.2 at level X if accessibility support existed for the following language\(s\):"

### 5.6 Privacy Considerations

This section is non-normative.

Success criteria within this specification which the Working Group has identified possible implications for privacy, either by providing protections for end users or which are important for website providers to take in to consideration when implementing features designed to protect user privacy, are listed below. This list reflects the current understanding of the Working Group but other Success criteria may have privacy implications that the Working Group is not aware of at the time of publishing.

Success criteria within this specification that may relate to privacy are:

- 2.2.6 Timeouts \(AAA\)
- 3.3.7 Redundant Entry \(A\)

### 5.7 Security Considerations

This section is non-normative.

Success criteria within this specification which the Working Group has identified possible implications for security, either by providing protections for end users or which are important for website providers to take in to consideration when implementing features designed to protect user security, are listed below. This list reflects the current understanding of the Working Group but other Success criteria may have security implications that the Working Group is not aware of at the time of publishing.

Success criteria within this specification that may relate to security are:

- 1.1.1 Non-text Content \(A\)
- 1.3.5 Identify Input Purpose \(AA\)
- 1.4.7 Low or No Background Audio \(AAA\)
- 2.2.1 Timing Adjustable \(A\)
- 2.2.5 Re-authenticating \(AAA\)
- 2.2.6 Timeouts \(AAA\)
- 2.5.6 Concurrent Input Mechanisms \(AAA\)
- 3.3.3 Error Suggestion \(AA\)
- 3.3.7 Redundant Entry \(A\)
- 3.3.8 Accessible Authentication \(Minimum\) \(AA\)
- 3.3.9 Accessible Authentication \(Enhanced\) \(AAA\)

## 6. Glossary

abbreviation

shortened form of a word, phrase, or name where the abbreviation has not become part of the language

Note 1

This includes initialisms and acronyms where:

initialisms are shortened forms of a name or phrase made from the initial letters of words or syllables contained in that name or phrase

Note 2

Not defined in all languages.

Example 1

SNCF is a French initialism that contains the initial letters of the Société Nationale des Chemins de Fer , the French national railroad.

Example 2

ESP is an initialism for extrasensory perception.

acronyms are abbreviated forms made from the initial letters or parts of other words \(in a name or phrase\) which may be pronounced as a word

Example 3

NOAA is an acronym made from the initial letters of the National Oceanic and Atmospheric Administration in the United States.

Note 3

Some companies have adopted what used to be an initialism as their company name. In these cases, the new name of the company is the letters \(for example, Ecma\) and the word is no longer considered an abbreviation.

accessibility supported

supported by users' assistive technologies as well as the accessibility features in browsers and other user agents

To qualify as an accessibility-supported use of a web content technology \(or feature of a technology\), both 1 and 2 must be satisfied for a web content technology \(or feature\):

The way that the web content technology is used must be supported by users' assistive technology \(AT\). This means that the way that the technology is used has been tested for interoperability with users' assistive technology in the human language\(s\) of the content,

AND

The web content technology must have accessibility-supported user agents that are available to users. This means that at least one of the following four statements is true:

The technology is supported natively in widely-distributed user agents that are also accessibility supported \(such as HTML and CSS\);

OR

The technology is supported in a widely-distributed plug-in that is also accessibility supported;

OR

The content is available in a closed environment, such as a university or corporate network, where the user agent required by the technology and used by the organization is also accessibility supported;

OR

The user agent\(s\) that support the technology are accessibility supported and are available for download or purchase in a way that:

- does not cost a person with a disability any more than a person without a disability and
- is as easy to find and obtain for a person with a disability as it is for a person without disabilities.

Note 1

The Accessibility Guidelines Working Group and the W3C do not specify which or how much support by assistive technologies there must be for a particular use of a web technology in order for it to be classified as accessibility supported. \(See Level of Assistive Technology Support Needed for "Accessibility Support" .\)

Note 2

Web technologies can be used in ways that are not accessibility supported as long as they are not relied upon and the page as a whole meets the conformance requirements, including Conformance Requirement 4 and Conformance Requirement 5 .

Note 3

When a web technology is used in a way that is "accessibility supported," it does not imply that the entire technology or all uses of the technology are supported. Most technologies, including HTML , lack support for at least one feature or use. Pages conform to WCAG only if the uses of the technology that are accessibility supported can be relied upon to meet WCAG requirements.

Note 4

When citing web content technologies that have multiple versions, the version\(s\) supported should be specified.

Note 5

One way for authors to locate uses of a technology that are accessibility supported would be to consult compilations of uses that are documented to be accessibility supported. \(See Understanding Accessibility-Supported Web Technology Uses .\) Authors, companies, technology vendors, or others may document accessibility-supported ways of using web content technologies. However, all ways of using technologies in the documentation would need to meet the definition of accessibility-supported Web content technologies above.

alternative for time-based media

document including correctly sequenced text descriptions of time-based visual and auditory information and providing a means for achieving the outcomes of any time-based interaction

Note

A screenplay used to create the synchronized media content would meet this definition only if it was corrected to accurately represent the final synchronized media after editing.

ambiguous to users in general

the purpose cannot be determined from the link and all information of the web page presented to the user simultaneously with the link \(i.e., readers without disabilities would not know what a link would do until they activated it\)

Example

The word guava in the following sentence "One of the notable exports is guava" is a link. The link could lead to a definition of guava, a chart listing the quantity of guava exported or a photograph of people harvesting guava. Until the link is activated, all readers are unsure and the person with a disability is not at any disadvantage.

ASCII art

picture created by a spatial arrangement of characters or glyphs \(typically from the 95 printable characters defined by ASCII\)

assistive technology \(as used in this document\)

hardware and/or software that acts as a user agent , or along with a mainstream user agent, to provide functionality to meet the requirements of users with disabilities that go beyond those offered by mainstream user agents

Note 1

Functionality provided by assistive technology includes alternative presentations \(e.g., as synthesized speech or magnified content\), alternative input methods \(e.g., voice\), additional navigation or orientation mechanisms, and content transformations \(e.g., to make tables more accessible\).

Note 2

Assistive technologies often communicate data and messages with mainstream user agents by using and monitoring APIs.

Note 3

The distinction between mainstream user agents and assistive technologies is not absolute. Many mainstream user agents provide some features to assist individuals with disabilities. The basic difference is that mainstream user agents target broad and diverse audiences that usually include people with and without disabilities. Assistive technologies target narrowly defined populations of users with specific disabilities. The assistance provided by an assistive technology is more specific and appropriate to the needs of its target users. The mainstream user agent may provide important functionality to assistive technologies like retrieving web content from program objects or parsing markup into identifiable bundles.

Example

Assistive technologies that are important in the context of this document include the following:

- screen magnifiers, and other visual reading assistants, which are used by people with visual, perceptual and physical print disabilities to change text font, size, spacing, color, synchronization with speech, etc. in order to improve the visual readability of rendered text and images;
- screen readers, which are used by people who are blind to read textual information through synthesized speech or braille;
- text-to-speech software, which is used by some people with cognitive, language, and learning disabilities to convert text into synthetic speech;
- speech recognition software, which may be used by people who have some physical disabilities;
- alternative keyboards, which are used by people with certain physical disabilities to simulate the keyboard \(including alternate keyboards that use head pointers, single switches, sip/puff and other special input devices.\);
- alternative pointing devices, which are used by people with certain physical disabilities to simulate mouse pointing and button activations.

audio

the technology of sound reproduction

Note

Audio can be created synthetically \(including speech synthesis\), recorded from real world sounds, or both.

audio description

narration added to the soundtrack to describe important visual details that cannot be understood from the main soundtrack alone

Note 1

Audio description of video provides information about actions, characters, scene changes, on-screen text, and other visual content.

Note 2

In standard audio description, narration is added during existing pauses in dialogue. \(See also extended audio description .\)

Note 3

Where all of the video information is already provided in existing audio , no additional audio description is necessary.

Note 4

Also called "video description" and "descriptive narration."

audio-only

a time-based presentation that contains only audio \(no video and no interaction\)

blinking

switch back and forth between two visual states in a way that is meant to draw attention

Note

See also flash . It is possible for something to be large enough and blink brightly enough at the right frequency to be also classified as a flash.

blocks of text

more than one sentence of text

CAPTCHA

initialism for "Completely Automated Public Turing test to tell Computers and Humans Apart"

Note 1

CAPTCHA tests often involve asking the user to type in text that is displayed in an obscured image or audio file.

Note 2

A Turing test is any system of tests designed to differentiate a human from a computer. It is named after famed computer scientist Alan Turing. The term was coined by researchers at Carnegie Mellon University.

captions

synchronized visual and/or text alternative for both speech and non-speech audio information needed to understand the media content

Note 1

Captions are similar to dialogue-only subtitles except captions convey not only the content of spoken dialogue, but also equivalents for non-dialogue audio information needed to understand the program content, including sound effects, music, laughter, speaker identification and location.

Note 2

Closed Captions are equivalents that can be turned on and off with some players.

Note 3

Open Captions are any captions that cannot be turned off. For example, if the captions are visual equivalent images of text embedded in video .

Note 4

Captions should not obscure or obstruct relevant information in the video.

Note 5

In some countries, captions are called subtitles.

Note 6

Audio descriptions can be, but do not need to be, captioned since they are descriptions of information that is already presented visually.

changes of context

major changes that, if made without user awareness, can disorient users who are not able to view the entire page simultaneously

Changes in context include changes of:

- user agent ;
- viewport ;
- focus;
- content that changes the meaning of the web page

Note

A change of content is not always a change of context. Changes in content, such as an expanding outline, dynamic menu, or a tab control do not necessarily change the context, unless they also change one of the above \(e.g., focus\).

Example

Opening a new window, moving focus to a different component, going to a new page \(including anything that would look to a user as if they had moved to a new page\) or significantly re-arranging the content of a page are examples of changes of context.

cognitive function test

New

A task that requires the user to remember, manipulate, or transcribe information. Examples include, but are not limited to:

- memorization, such as remembering a username, password, set of characters, images, or patterns. The common identifiers name, e-mail, and phone number are not considered cognitive function tests as they are personal to the user and consistent across websites;
- transcription, such as typing in characters;
- use of correct spelling;
- performance of calculations;
- solving of puzzles.

conformance

satisfying all the requirements of a given standard, guideline or specification

conforming alternate version

version that

- conforms at the designated level, and
- provides all of the same information and functionality in the same human language , and
- is as up to date as the non-conforming content, and

for which at least one of the following is true:

- the conforming version can be reached from the non-conforming page via an accessibility-supported mechanism , or
- the non-conforming version can only be reached from the conforming version, or
- the non-conforming version can only be reached from a conforming page that also provides a mechanism to reach the conforming version

Note 1

In this definition, "can only be reached" means that there is some mechanism, such as a conditional redirect, that prevents a user from "reaching" \(loading\) the non-conforming page unless the user had just come from the conforming version.

Note 2

The alternate version does not need to be matched page for page with the original \(e.g., the conforming alternate version may consist of multiple pages\).

Note 3

If multiple language versions are available, then conforming alternate versions are required for each language offered.

Note 4

Alternate versions may be provided to accommodate different technology environments or user groups. Each version should be as conformant as possible. One version would need to be fully conformant in order to meet conformance requirement 1 .

Note 5

The conforming alternative version does not need to reside within the scope of conformance, or even on the same website, as long as it is as freely available as the non-conforming version.

Note 6

Alternate versions should not be confused with supplementary content , which support the original page and enhance comprehension.

Note 7

Setting user preferences within the content to produce a conforming version is an acceptable mechanism for reaching another version as long as the method used to set the preferences is accessibility supported.

See Understanding Conforming Alternate Versions

content \(web content\)

information and sensory experience to be communicated to the user by means of a user agent , including code or markup that defines the content's structure , presentation , and interactions

context-sensitive help

help text that provides information related to the function currently being performed

Note

Clear labels can act as context-sensitive help.

contrast ratio

\(L1 \+ 0.05\) / \(L2 \+ 0.05\), where

- L1 is the relative luminance of the lighter of the colors, and
- L2 is the relative luminance of the darker of the colors.

Note 1

Contrast ratios can range from 1 to 21 \(commonly written 1:1 to 21:1\).

Note 2

Because authors do not have control over user settings as to how text is rendered \(for example font smoothing or anti-aliasing\), the contrast ratio for text can be evaluated with anti-aliasing turned off.

Note 3

For the purpose of Success Criteria 1.4.3 and 1.4.6, contrast is measured with respect to the specified background over which the text is rendered in normal usage. If no background color is specified, then white is assumed.

Note 4

Background color is the specified color of content over which the text is to be rendered in normal usage. It is a failure if no background color is specified when the text color is specified, because the user's default background color is unknown and cannot be evaluated for sufficient contrast. For the same reason, it is a failure if no text color is specified when a background color is specified.

Note 5

When there is a border around the letter, the border can add contrast and would be used in calculating the contrast between the letter and its background. A narrow border around the letter would be used as the letter. A wide border around the letter that fills in the inner details of the letters acts as a halo and would be considered background.

Note 6

WCAG conformance should be evaluated for color pairs specified in the content that an author would expect to appear adjacent in typical presentation. Authors need not consider unusual presentations, such as color changes made by the user agent, except where caused by authors' code.

correct reading sequence

any sequence where words and paragraphs are presented in an order that does not change the meaning of the content

CSS pixel

visual angle of about 0.0213 degrees

A CSS pixel is the canonical unit of measure for all lengths and measurements in CSS. This unit is density-independent, and distinct from actual hardware pixels present in a display. User agents and operating systems should ensure that a CSS pixel is set as closely as possible to the CSS Values and Units Module Level 3 reference pixel \[ css3-values \], which takes into account the physical dimensions of the display and the assumed viewing distance \(factors that cannot be determined by content authors\).

down-event

platform event that occurs when the trigger stimulus of a pointer is depressed

The down-event may have different names on different platforms, such as "touchstart" or "mousedown".

dragging movement

New

an operation where the pointer engages with an element on the down-event and the element \(or a representation of its position\) follows the pointer until an up-event

Note

Examples of draggable elements include list items, text elements, and images.

emergency

a sudden, unexpected situation or occurrence that requires immediate action to preserve health, safety, or property

essential

if removed, would fundamentally change the information or functionality of the content, and information and functionality cannot be achieved in another way that would conform

extended audio description

audio description that is added to an audiovisual presentation by pausing the video so that there is time to add additional description

Note

This technique is only used when the sense of the video would be lost without the additional audio description and the pauses between dialogue/narration are too short.

flash

a pair of opposing changes in relative luminance that can cause seizures in some people if it is large enough and in the right frequency range

Note 1

See general flash and red flash thresholds for information about types of flash that are not allowed.

Note 2

See also blinking .

focus indicator

New

pixels that are changed to visually indicate when a user interface component is in a focused state

functionality

processes and outcomes achievable through user action

general flash and red flash thresholds

a flash or rapidly changing image sequence is below the threshold \(i.e., content passes \) if any of the following are true:

- there are no more than three general flashes and / or no more than three red flashes within any one-second period; or
- the combined area of flashes occurring concurrently occupies no more than a total of .006 steradians within any 10 degree visual field on the screen \(25% of any 10 degree visual field on the screen\) at typical viewing distance

where:

- A general flash is defined as a pair of opposing changes in relative luminance of 10% or more of the maximum relative luminance \(1.0\) where the relative luminance of the darker image is below 0.80; and where "a pair of opposing changes" is an increase followed by a decrease, or a decrease followed by an increase, and
- A red flash is defined as any pair of opposing transitions involving a saturated red

Exception: Flashing that is a fine, balanced, pattern such as white noise or an alternating checkerboard pattern with "squares" smaller than 0.1 degree \(of visual field at typical viewing distance\) on a side does not violate the thresholds.

Note 1

For general software or web content, using a 341 x 256 pixel rectangle anywhere on the displayed screen area when the content is viewed at 1024 x 768 pixels will provide a good estimate of a 10 degree visual field for standard screen sizes and viewing distances \(e.g., 15-17 inch screen at 22-26 inches\). This resolution of 75 - 85 ppi is known to be lower, and thus more conservative than the nominal CSS pixel resolution of 96 ppi in CSS specifications. Higher resolutions displays showing the same rendering of the content yield smaller and safer images so it is lower resolutions that are used to define the thresholds.

Note 2

A transition is the change in relative luminance \(or relative luminance/color for red flashing\) between adjacent peaks and valleys in a plot of relative luminance \(or relative luminance/color for red flashing\) measurement against time. A flash consists of two opposing transitions.

Note 3

The new working definition in the field for "pair of opposing transitions involving a saturated red" \(from WCAG 2.2\) is a pair of opposing transitions where, one transition is either to or from a state with a value R/\(R \+ G \+ B\) that is greater than or equal to 0.8, and the difference between states is more than 0.2 \(unitless\) in the CIE 1976 UCS chromaticity diagram. \[ ISO\_9241-391 \]

Note 4

Tools are available that will carry out analysis from video screen capture. However, no tool is necessary to evaluate for this condition if flashing is less than or equal to 3 flashes in any one second. Content automatically passes \(see \#1 and \#2 above\).

human language

language that is spoken, written or signed \(through visual or tactile means\) to communicate with humans

Note

See also sign language .

idiom

phrase whose meaning cannot be deduced from the meaning of the individual words and the specific words cannot be changed without losing the meaning

Note

Idioms cannot be translated directly, word for word, without losing their \(cultural or language-dependent\) meaning.

Example 1

In English, "spilling the beans" means "revealing a secret." However, "knocking over the beans" or "spilling the vegetables" does not mean the same thing.

Example 2

In Japanese, the phrase " さじを投げる " literally translates into "he throws a spoon," but it means that there is nothing he can do and finally he gives up.

Example 3

In Dutch, " Hij ging met de kippen op stok " literally translates into "He went to roost with the chickens," but it means that he went to bed early.

image of text

text that has been rendered in a non-text form \(e.g., an image\) in order to achieve a particular visual effect

Note

This does not include text that is part of a picture that contains significant other visual content.

Example

A person's name on a nametag in a photograph.

informative

for information purposes and not required for conformance

Note

Content required for conformance is referred to as " normative ."

input error

information provided by the user that is not accepted

Note

This includes:

- Information that is required by the web page but omitted by the user
- Information that is provided by the user but that falls outside the required data format or values

jargon

words used in a particular way by people in a particular field

Example

The word StickyKeys is jargon from the field of assistive technology/accessibility.

keyboard interface

interface used by software to obtain keystroke input

Note 1

A keyboard interface allows users to provide keystroke input to programs even if the native technology does not contain a keyboard.

Example

A touchscreen PDA has a keyboard interface built into its operating system as well as a connector for external keyboards. Applications on the PDA can use the interface to obtain keyboard input either from an external keyboard or from other applications that provide simulated keyboard output, such as handwriting interpreters or speech-to-text applications with "keyboard emulation" functionality.

Note 2

Operation of the application \(or parts of the application\) through a keyboard-operated mouse emulator, such as MouseKeys, does not qualify as operation through a keyboard interface because operation of the program is through its pointing device interface, not through its keyboard interface.

keyboard shortcut

alternative means of triggering an action by the pressing of one or more keys

label

text or other component with a text alternative that is presented to a user to identify a component within web content

Note 1

A label is presented to all users whereas the name may be hidden and only exposed by assistive technology. In many \(but not all\) cases the name and the label are the same.

Note 2

The term label is not limited to the label element in HTML .

large scale \(text\)

with at least 18 point or 14 point bold or font size that would yield equivalent size for Chinese, Japanese and Korean \(CJK\) fonts

Note 1

Fonts with extraordinarily thin strokes or unusual features and characteristics that reduce the familiarity of their letter forms are harder to read, especially at lower contrast levels.

Note 2

Font size is the size when the content is delivered. It does not include resizing that may be done by a user.

Note 3

The actual size of the character that a user sees is dependent both on the author-defined size and the user's display or user agent settings. For many mainstream body text fonts, 14 and 18 point is roughly equivalent to 1.2 and 1.5 em or to 120% or 150% of the default size for body text \(assuming that the body font is 100%\), but authors would need to check this for the particular fonts in use. When fonts are defined in relative units, the actual point size is calculated by the user agent for display. The point size should be obtained from the user agent, or calculated based on font metrics as the user agent does, when evaluating this success criterion. Users who have low vision would be responsible for choosing appropriate settings.

Note 4

When using text without specifying the font size, the smallest font size used on major browsers for unspecified text would be a reasonable size to assume for the font. If a level 1 heading is rendered in 14pt bold or higher on major browsers, then it would be reasonable to assume it is large text. Relative scaling can be calculated from the default sizes in a similar fashion.

Note 5

The 18 and 14 point sizes for roman texts are taken from the minimum size for large print \(14pt\) and the larger standard font size \(18pt\). For other fonts such as CJK languages, the "equivalent" sizes would be the minimum large print size used for those languages and the next larger standard large print size.

legal commitments

transactions where the person incurs a legally binding obligation or benefit

Example

A marriage license, a stock trade \(financial and legal\), a will, a loan, adoption, signing up for the army, a contract of any type, etc.

link purpose

nature of the result obtained by activating a hyperlink

live

information captured from a real-world event and transmitted to the receiver with no more than a broadcast delay

Note 1

A broadcast delay is a short \(usually automated\) delay, for example used in order to give the broadcaster time to cue or censor the audio \(or video\) feed, but not sufficient to allow significant editing.

Note 2

If information is completely computer generated, it is not live.

lower secondary education level

the two or three year period of education that begins after completion of six years of school and ends nine years after the beginning of primary education

Note

This definition is based on the International Standard Classification of Education \[ UNESCO \].

mechanism

process or technique for achieving a result

Note 1

The mechanism may be explicitly provided in the content, or may be relied upon to be provided by either the platform or by user agents , including assistive technologies .

Note 2

The mechanism needs to meet all success criteria for the conformance level claimed.

media alternative for text

media that presents no more information than is already presented in text \(directly or via text alternatives\)

Note

A media alternative for text is provided for those who benefit from alternate representations of text. Media alternatives for text may be audio-only, video-only \(including sign-language video\), or audio-video.

motion animation

addition of steps between conditions to create the illusion of movement or to give a sense of a smooth transition

Example

For example, an element which moves into place or changes size while appearing is considered to be animated. An element which appears instantly without transitioning is not using animation. Motion animation does not include changes of color, blurring, or opacity which do not change the perceived size, shape, or position of the element.

minimum bounding box

New

the smallest enclosing rectangle aligned to the horizontal axis within which all the points of a shape lie. For components which wrap onto multiple lines as part of a sentence or block of text \(such as hypertext links\), the bounding box is based on how the component would appear on a single line.

name

text by which software can identify a component within web content to the user

Note 1

The name may be hidden and only exposed by assistive technology, whereas a label is presented to all users. In many \(but not all\) cases, the label and the name are the same.

Note 2

This is unrelated to the name attribute in HTML .

navigated sequentially

navigated in the order defined for advancing focus \(from one element to the next\) using a keyboard interface

non-text content

any content that is not a sequence of characters that can be programmatically determined or where the sequence is not expressing something in human language

Note

This includes ASCII art \(which is a pattern of characters\), emoticons, leetspeak \(which uses character substitution\), and images representing text

normative

required for conformance

Note 1

One may conform in a variety of well-defined ways to this document.

Note 2

Content identified as " informative " or "non-normative" is never required for conformance .

on a full-screen window

on the most common sized desktop/laptop display with the viewport maximized

Note

Since people generally keep their computers for several years, it is best not to rely on the latest desktop/laptop display resolutions but to consider the common desktop/laptop display resolutions over the course of several years when making this evaluation.

paused

stopped by user request and not resumed until requested by user

perimeter

New

continuous line forming the boundary of a shape not including shared pixels, or the minimum bounding box , whichever is shortest.

Example

The perimeter calculation for a 2 CSS pixel perimeter around a rectangle is 4 h \+4 w , where h is the height and w is the width. For a 2 CSS pixel perimeter around a circle it is 4&#120587; r .

pointer input

input from a device that can target a specific coordinate \(or set of coordinates\) on a screen, such as a mouse, pen, or touch contact

Note

See the Pointer Events definition for "pointer" \[ pointerevents \].

prerecorded

information that is not live

presentation

rendering of the content in a form to be perceived by users

primary education level

six year time period that begins between the ages of five and seven, possibly without any previous education

Note

This definition is based on the International Standard Classification of Education \[ UNESCO \].

process

series of user actions where each action is required in order to complete an activity

Example 1

Successful use of a series of web pages on a shopping site requires users to view alternative products, prices and offers, select products, submit an order, provide shipping information and provide payment information.

Example 2

An account registration page requires successful completion of a Turing test before the registration form can be accessed.

programmatically determined \(programmatically determinable\)

determined by software from author-supplied data provided in a way that different user agents , including assistive technologies , can extract and present this information to users in different modalities

Example 1

Determined in a markup language from elements and attributes that are accessed directly by commonly available assistive technology.

Example 2

Determined from technology-specific data structures in a non-markup language and exposed to assistive technology via an accessibility API that is supported by commonly available assistive technology.

programmatically determined link context

additional information that can be programmatically determined from relationships with a link, combined with the link text, and presented to users in different modalities

Example

In HTML , information that is programmatically determinable from a link in English includes text that is in the same paragraph , list item, or table cell as the link or in a table header cell that is associated with the table cell that contains the link.

Note

Since screen readers interpret punctuation, they can also provide the context from the current sentence, when the focus is on a link in that sentence.

programmatically set

set by software using methods that are supported by user agents , including assistive technologies

pure decoration

serving only an aesthetic purpose, providing no information, and having no functionality

Note

Text is only purely decorative if the words can be rearranged or substituted without changing their purpose.

Example

The cover page of a dictionary has random words in very light text in the background.

real-time event

event that a\) occurs at the same time as the viewing and b\) is not completely generated by the content

Example 1

A Webcast of a live performance \(occurs at the same time as the viewing and is not prerecorded\).

Example 2

An on-line auction with people bidding \(occurs at the same time as the viewing\).

Example 3

Live humans interacting in a virtual world using avatars \(is not completely generated by the content and occurs at the same time as the viewing\).

region

perceivable, programmatically determined section of content

Note

In HTML , any area designated with a landmark role would be a region.

relationships

meaningful associations between distinct pieces of content

relative luminance

the relative brightness of any point in a colorspace, normalized to 0 for darkest black and 1 for lightest white

Note 1

For the sRGB colorspace, the relative luminance of a color is defined as L = 0.2126 \* R \+ 0.7152 \* G \+ 0.0722 \* B where R , G and B are defined as:

- if RsRGB \<= 0.04045 then R = RsRGB/12.92 else R = \(\(RsRGB\+0.055\)/1.055\) ^ 2.4
- if GsRGB \<= 0.04045 then G = GsRGB/12.92 else G = \(\(GsRGB\+0.055\)/1.055\) ^ 2.4
- if BsRGB \<= 0.04045 then B = BsRGB/12.92 else B = \(\(BsRGB\+0.055\)/1.055\) ^ 2.4

and RsRGB, GsRGB, and BsRGB are defined as:

- RsRGB = R8bit/255
- GsRGB = G8bit/255
- BsRGB = B8bit/255

The "^" character is the exponentiation operator. \(Formula taken from \[ SRGB \].\)

Note 2

Before May 2021 the value of 0.04045 in the definition was different \(0.03928\). It was taken from an older version of the specification and has been updated. It has no practical effect on the calculations in the context of these guidelines.

Note 3

Almost all systems used today to view web content assume sRGB encoding. Unless it is known that another color space will be used to process and display the content, authors should evaluate using sRGB colorspace. If using other color spaces, see Understanding Success Criterion 1.4.3 .

Note 4

If dithering occurs after delivery, then the source color value is used. For colors that are dithered at the source, the average values of the colors that are dithered should be used \(average R, average G, and average B\).

Note 5

Tools are available that automatically do the calculations when testing contrast and flash.

Note 6

A separate page giving the relative luminance definition using MathML to display the formulas is available.

relied upon \(technologies that are\)

the content would not conform if that technology is turned off or is not supported

role

text or number by which software can identify the function of a component within Web content

Example

A number that indicates whether an image functions as a hyperlink, command button, or check box.

same functionality

same result when used

Example

A submit "search" button on one web page and a "find" button on another web page may both have a field to enter a term and list topics in the website related to the term submitted. In this case, they would have the same functionality but would not be labeled consistently.

same relative order

same position relative to other items

Note

Items are considered to be in the same relative order even if other items are inserted or removed from the original order. For example, expanding navigation menus may insert an additional level of detail or a secondary navigation section may be inserted into the reading order.

satisfies a success criterion

the success criterion does not evaluate to 'false' when applied to the page

section

a self-contained portion of written content that deals with one or more related topics or thoughts

Note

A section may consist of one or more paragraphs and include graphics, tables, lists and sub-sections.

set of web pages

collection of web pages that share a common purpose and that are created by the same author, group or organization

Example

Examples include:

- a publication which is split across multiple web pages, where each page contains one chapter or other significant section of the work. The publication is logically a single contiguous unit, and contains navigation features that enable access to the full set of pages.
- an e-commerce website shows products in a set of web pages that all share the same navigation and identification. However, when progressing to the checkout process, the template changes; the navigation and other elements are removed, so the pages in that process are functionally and visually different. The checkout pages are not part of the set of product pages.
- a blog on a sub-domain \(e.g. blog.example.com\) which has a different navigation and is authored by a distinct set of people from the pages on the primary domain \(example.com\).

Note

Different language versions would be considered different sets of web pages.

sign language

a language using combinations of movements of the hands and arms, facial expressions, or body positions to convey meaning

sign language interpretation

translation of one language, generally a spoken language, into a sign language

Note

True sign languages are independent languages that are unrelated to the spoken language\(s\) of the same country or region.

single pointer

an input modality that only targets a single point on the page/screen at a time – such as a mouse, single finger on a touch screen, or stylus.

Note

Single pointer interactions include clicks, double clicks, taps, dragging motions, and single-finger swipe gestures. In contrast, multipoint interactions involve the use of two or more pointers at the same time, such as two-finger interactions on a touchscreen, or the simultaneous use of a mouse and stylus.

specific sensory experience

a sensory experience that is not purely decorative and does not primarily convey important information or perform a function

Example

Examples include a performance of a flute solo, works of visual art etc.

state

dynamic property expressing characteristics of a user interface component that may change in response to user action or automated processes

States do not affect the nature of the component, but represent data associated with the component or user interaction possibilities. Examples include focus, hover, select, press, check, visited/unvisited, and expand/collapse.

status message

change in content that is not a change of context , and that provides information to the user on the success or results of an action, on the waiting state of an application, on the progress of a process , or on the existence of errors

structure

- The way the parts of a web page are organized in relation to each other; and
- The way a collection of web pages is organized

style property

property whose value determines the presentation \(e.g. font, color, size, location, padding, volume, synthesized speech prosody\) of content elements as they are rendered \(e.g. onscreen, via loudspeaker, via braille display\) by user agents

Style properties can have several origins:

- User agent default styles: The default style property values applied in the absence of any author or user styles. Some web content technologies specify a default rendering, others do not;
- Author styles: Style property values that are set by the author as part of the content \(e.g. in-line styles, author style sheets\);
- User styles: Style property values that are set by the user \(e.g. via user agent interface settings, user style sheets\)

supplemental content

additional content that illustrates or clarifies the primary content

Example 1

An audio version of a web page .

Example 2

An illustration of a complex process .

Example 3

A paragraph summarizing the major outcomes and recommendations made in a research study.

synchronized media

audio or video synchronized with another format for presenting information and/or with time-based interactive components, unless the media is a media alternative for text that is clearly labeled as such

target

region of the display that will accept a pointer action, such as the interactive area of a user interface component

Note

If two or more targets are overlapping, the overlapping area should not be included in the measurement of the target size, except when the overlapping targets perform the same action or open the same page.

technology \(web content\)

mechanism for encoding instructions to be rendered, played or executed by user agents

Note 1

As used in these guidelines "web technology" and the word "technology" \(when used alone\) both refer to web content technologies.

Note 2

Web content technologies may include markup languages, data formats, or programming languages that authors may use alone or in combination to create end-user experiences that range from static web pages to synchronized media presentations to dynamic Web applications.

Example

Some common examples of web content technologies include HTML , CSS, SVG, PNG, PDF, Flash, and JavaScript.

text

sequence of characters that can be programmatically determined , where the sequence is expressing something in human language

text alternative

Text that is programmatically associated with non-text content or referred to from text that is programmatically associated with non-text content. Programmatically associated text is text whose location can be programmatically determined from the non-text content.

Example

An image of a chart is described in text in the paragraph after the chart. The short text alternative for the chart indicates that a description follows.

Note

Refer to Understanding Text Alternatives for more information.

up-event

platform event that occurs when the trigger stimulus of a pointer is released

The up-event may have different names on different platforms, such as "touchend" or "mouseup".

used in an unusual or restricted way

words used in such a way that requires users to know exactly which definition to apply in order to understand the content correctly

Example

The term "gig" means something different if it occurs in a discussion of music concerts than it does in article about computer hard drive space, but the appropriate definition can be determined from context. By contrast, the word "text" is used in a very specific way in WCAG 2, so a definition is supplied in the glossary.

user agent

any software that retrieves and presents web content for users

Example

Web browsers, media players, plug-ins, and other programs — including assistive technologies — that help in retrieving, rendering, and interacting with web content.

user-controllable

data that is intended to be accessed by users

Note

This does not refer to such things as Internet logs and search engine monitoring data.

Example

Name and address fields for a user's account.

user interface component

a part of the content that is perceived by users as a single control for a distinct function

Note 1

Multiple user interface components may be implemented as a single programmatic element. "Components" here is not tied to programming techniques, but rather to what the user perceives as separate controls.

Note 2

User interface components include form elements and links as well as components generated by scripts.

Note 3

What is meant by "component" or "user interface component" here is also sometimes called "user interface element".

Example

An applet has a "control" that can be used to move through content by line or page or random access. Since each of these would need to have a name and be settable independently, they would each be a "user interface component."

user inactivity

any continuous period of time where no user actions occur

The method of tracking will be determined by the website or application.

video

the technology of moving or sequenced pictures or images

Note

Video can be made up of animated or photographic images, or both.

video-only

a time-based presentation that contains only video \(no audio and no interaction\)

viewport

object in which the user agent presents content

Note 1

The user agent presents content through one or more viewports. Viewports include windows, frames, loudspeakers, and virtual magnifying glasses. A viewport may contain another viewport \(e.g., nested frames\). Interface components created by the user agent such as prompts, menus, and alerts are not viewports.

Note 2

This definition is based on User Agent Accessibility Guidelines 1.0 Glossary \[ UAAG10 \].

visually customized

the font, size, color, and background can be set

web page

a non-embedded resource obtained from a single URI using HTTP plus any other resources that are used in the rendering or intended to be rendered together with it by a user agent

Note 1

Although any "other resources" would be rendered together with the primary resource, they would not necessarily be rendered simultaneously with each other.

Note 2

For the purposes of conformance with these guidelines, a resource must be "non-embedded" within the scope of conformance to be considered a web page.

Example 1

A web resource including all embedded images and media.

Example 2

A web mail program built using Asynchronous JavaScript and XML \(AJAX\). The program lives entirely at http://example.com/mail, but includes an inbox, a contacts area and a calendar. Links or buttons are provided that cause the inbox, contacts, or calendar to display, but do not change the URI of the page as a whole.

Example 3

A customizable portal site, where users can choose content to display from a set of different content modules.

Example 4

When you enter "http://shopping.example.com/" in your browser, you enter a movie-like interactive shopping environment where you visually move around in a store dragging products off of the shelves around you and into a visual shopping cart in front of you. Clicking on a product causes it to be demonstrated with a specification sheet floating alongside. This might be a single-page website or just one page within a website.

## 7. Input Purposes for User Interface Components

This section contains a listing of common user interface component input purposes. The terms below are not keywords that must be used, but instead represent purposes that must be captured in the taxonomy adopted by a webpage. Where applicable, authors mark up controls with the chosen taxonomy to indicate the semantic purpose. This provides the potential for user agents and assistive technologies to apply personalized presentations that can enable more people to understand and use the content.

Note

The list of input type purposes is based on the control purposes defined in the HTML specification's Autofill section , but it is important to understand that a different technology may have some or all of the same concepts defined in its specification and only the concepts that are mapped to the meanings below are required.

The following input control purposes are intended to relate to the user of the content and pertain only to information related to that individual.

- name - Full name
- honorific-prefix - Prefix or title \(e.g., "Mr.", "Ms.", "Dr.", "M lle "\)
- given-name - Given name \(in some Western cultures, also known as the first name \)
- additional-name - Additional names \(in some Western cultures, also known as middle names , forenames other than the first name\)
- family-name - Family name \(in some Western cultures, also known as the last name or surname \)
- honorific-suffix - Suffix \(e.g., "Jr.", "B.Sc.", "MBASW", "II"\)
- nickname - Nickname, screen name, handle: a typically short name used instead of the full name
- organization-title - Job title \(e.g., "Software Engineer", "Senior Vice President", "Deputy Managing Director"\)
- username - A username
- new-password - A new password \(e.g., when creating an account or changing a password\)
- current-password - The current password for the account identified by the username field \(e.g., when logging in\)
- organization - Company name corresponding to the person, address, or contact information in the other fields associated with this field
- street-address - Street address \(multiple lines, newlines preserved\)
- address-line1 - Street address \(one line per field, line 1\)
- address-line2 - Street address \(one line per field, line 2\)
- address-line3 - Street address \(one line per field, line 3\)
- address-level4 - The most fine-grained administrative level, in addresses with four administrative levels
- address-level3 - The third administrative level, in addresses with three or more administrative levels
- address-level2 - The second administrative level, in addresses with two or more administrative levels; in the countries with two administrative levels, this would typically be the city, town, village, or other locality within which the relevant street address is found
- address-level1 - The broadest administrative level in the address, i.e., the province within which the locality is found; for example, in the US, this would be the state; in Switzerland it would be the canton; in the UK, the post town
- country - Country code
- country-name - Country name
- postal-code - Postal code, post code, ZIP code, CEDEX code \(if CEDEX, append "CEDEX", and the arrondissement , if relevant, to the address-level2 field\)
- cc-name - Full name as given on the payment instrument
- cc-given-name - Given name as given on the payment instrument \(in some Western cultures, also known as the first name \)
- cc-additional-name - Additional names given on the payment instrument \(in some Western cultures, also known as middle names , forenames other than the first name\)
- cc-family-name - Family name given on the payment instrument \(in some Western cultures, also known as the last name or surname \)
- cc-number - Code identifying the payment instrument \(e.g., the credit card number\)
- cc-exp - Expiration date of the payment instrument
- cc-exp-month - Month component of the expiration date of the payment instrument
- cc-exp-year - Year component of the expiration date of the payment instrument
- cc-csc - Security code for the payment instrument \(also known as the card security code \(CSC\), card validation code \(CVC\), card verification value \(CVV\), signature panel code \(SPC\), credit card ID \(CCID\), etc\)
- cc-type - Type of payment instrument
- transaction-currency - The currency that the user would prefer the transaction to use
- transaction-amount - The amount that the user would like for the transaction \(e.g., when entering a bid or sale price\)
- language - Preferred language
- bday - Birthday
- bday-day - Day component of birthday
- bday-month - Month component of birthday
- bday-year - Year component of birthday
- sex - Gender identity \(e.g., Female, Fa’afafine \)
- url - Home page or other web page corresponding to the company, person, address, or contact information in the other fields associated with this field
- photo - Photograph, icon, or other image corresponding to the company, person, address, or contact information in the other fields associated with this field
- tel - Full telephone number, including country code
- tel-country-code - Country code component of the telephone number
- tel-national - Telephone number without the country code component, with a country-internal prefix applied if applicable
- tel-area-code - Area code component of the telephone number, with a country-internal prefix applied if applicable
- tel-local - Telephone number without the country code and area code components
- tel-local-prefix - First part of the component of the telephone number that follows the area code, when that component is split into two components
- tel-local-suffix - Second part of the component of the telephone number that follows the area code, when that component is split into two components
- tel-extension - Telephone number internal extension code
- email - E-mail address
- impp - URL representing an instant messaging protocol endpoint \(for example, " aim:goim?screenname=example " or " xmpp:fred@example.net "\)

## A. Change Log

This section shows substantive changes incorporated into WCAG 2.2 since WCAG 2.1, as well as changes made to 2.2 since its original publication on 05 October 2023. Errata fixes to WCAG 2.1 have also been incorporated into WCAG 2.2.

The full commit history to WCAG 2.2 is available.

- 2020-03-30: Added Accessible Authentication \(Minimum\) .
- 2020-05-27: Added Dragging \(later renamed Dragging Movements \).
- 2020-07-19: Added Findable Help \(later renamed to Consistent Help \), Pointer Target Spacing \(later renamed Target Size \(Minimum\) \), and Redundant Entry .
- 2020-08-04: Added Focus Appearance \(Minimum\) \(later renamed to Focus Appearance \).
- 2021-09-21: Added Accessible Authentication \(No Exception\) \(later renamed Accessible Authentication \(Enhanced\)\) .
- 2022-03-22: Added Focus Not Obscured \(Minimum\) .
- 2022-05-30: Added Focus Not Obscured \(Enhanced\) .
- 2023-06-05: Added privacy and security sections within conformance.
- 2024-12-12: Republished WCAG 2.2, incorporating the following errata:
- modified the definitions of single pointer , used in an unusual or restricted way , motion animation , and programmatically determined
- modified the formatting of definitions for changes of context , general flash and red flash thresholds , cognitive function test , and structure
- removed the defunct encloses definition
- corrected typo in input purposes list
- modified the formatting of Target Size \(Minimum\) and Accessible Authentication \(Minimum\)
- modified the visual presentation for content identified as New
- modified the language covering devices in the Abstract
- made editorial changes to improve consistent use of definitions in the success criteria
- made editorial changes to improve consistent use of the terms success criteria/criterion , web , website , and web page

## B. Acknowledgments

This section is non-normative.

Additional information about participation in the Accessibility Guidelines Working Group \(AG WG\) can be found on the Working Group home page .

### B.1 Participants of the AG WG active in the development of this document:

- Jake Abma \(Invited Expert\)
- Shadi Abou-Zahra \(Amazon\)
- Chuck Adams \(Oracle Corporation\)
- Amani Ali \(Nomensa\)
- Jim Allan \(Invited Expert\)
- Jon Avila \(Level Access\)
- Bruce Bailey \(U.S. Access Board\)
- Renaldo Bernard \(University of Southampton\)
- Dan Bjorge \(Deque Systems, Inc.\)
- Peter Bossley \(Thomson Reuters\)
- Rachael Bradley Montgomery \(Library of Congress\)
- Judy Brewer \( W3C \)
- Shari Butler \(Pearson plc\)
- Thaddeus Cambron \(Invited Expert\)
- Alastair Campbell \(Nomensa\)
- Laura Carlson \(Invited Expert\)
- Sukriti Chadha \(Invited Expert\)
- Rafal Charlampowicz \(AccessibilityOZ\)
- Michael Cooper \( W3C \)
- Jennifer Delisi \(Invited Expert\)
- Wayne Dick \(Knowbility, Inc\)
- Kim Dirks \(Thomson Reuters\)
- E.A. Draffan \(University of Southampton\)
- Eric Eggert \( W3C \)
- Michael Elledge \(Invited Expert\)
- Steve Faulkner \(TPGi\)
- David Fazio \(Invited Expert\)
- Wilco Fiers \(Deque Systems, Inc.\)
- Detlev Fischer \(Invited Expert\)
- John Foliot \(Invited Expert\)
- Matt Garrish \(DAISY Consortium\)
- Alistair Garrison \(Level Access\)
- Jaunita George \(Navy Federal Credit Union\)
- Michael Gower \(IBM Corporation\)
- Markku Hakkinen \(Educational Testing Service\)
- Charles Hall \(Invited Expert\)
- Katie Haritos-Shea \(Knowbility, Inc\)
- Dan Harper-Wain \(HM Government\)
- Shawn Henry \( W3C \)
- Sarah Horton \(Invited Expert\)
- Abi James \(University of Southampton\)
- Marc Johlic \(IBM Corporation\)
- Oliver Keim \(SAP SE\)
- Andrew Kirkpatrick \(Adobe\)
- John Kirkwood \(Invited Expert\)
- JaEun Jemma Ku \(University of Illinois Chicago\)
- Patrick H. Lauke \(TetraLogical\)
- Shawn Lauriat \(Google, Inc.\)
- Steve Lee \(Invited Expert\)
- Chris Loiselle \(Invited Expert\)
- David MacDonald \(Invited Expert\)
- Jan McSorley \(Pearson plc\)
- Rain Breaw Michaels \(Google LLC\)
- Neil Milliken \(Unify Software and Solutions\)
- Mary Jo Mueller \(IBM Corporation\)
- Jay Mullen \(College Board\)
- Brooks Newton \(Thomson Reuters\)
- Gundula Niemann \(SAP SE\)
- James Nurthen \(Oracle Corporation\)
- Lori Oakley \(Oracle Corporation\)
- Joshue O Connor \(Invited Expert\)
- Scott O'Hara \(Microsoft\)
- Sailesh Panchang \(Deque Systems, Inc.\)
- Kim Patch \(Invited Expert\)
- Melanie Philipp \(Deque Systems, Inc.\)
- Mike Pluke \(Invited Expert\)
- Ian Pouncey \(TetraLogical\)
- Ruoxi Ran \( W3C \)
- Stephen Repsher \(Invited Expert\)
- John Rochford \(Invited Expert\)
- Stefan Schnabel \(SAP SE\)
- Ayelet Seeman \(Invited Expert\)
- Lisa Seeman-Kestenbaum \(Invited Expert\)
- Glenda Sims \(Deque Systems, Inc.\)
- Avneesh Singh \(DAISY Consortium\)
- David Sloan \(TPGi\)
- Andrew Somers \(Invited Expert\)
- Jeanne Spellman \(TetraLogical\)
- Francis Storr \(Intel\)
- Poornima Badhan Subramanian \(Invited Expert\)
- Ben Tillyer \(Invited Expert\)
- Makoto Ueki \(Invited Expert\)
- Gregg Vanderheiden \(Raising the Floor\)
- Kathleen Wahlbin \(Invited Expert\)
- Léonie Watson \(TetraLogical\)
- Jason White \(Educational Testing Service\)
- White, Kevin \( W3C Staff\)
- Mark Wilcock \(Unify Software and Solutions\)

### B.2 Other previously active WCAG WG participants and other contributors to WCAG 2.0, WCAG 2.1, or supporting resources

Paul Adam, Jenae Andershonis, Wilhelm Joys Andersen, Andrew Arch, Avi Arditti, Aries Arditi, Tom Babinszki, Mark Barratt, Mike Barta, Sandy Bartell, Kynn Bartlett, Chris Beer, Charles Belov, Marco Bertoni, Harvey Bingham, Chris Blouch, Paul Bohman, Frederick Boland, Denis Boudreau, Patrice Bourlon, Andy Brown, Dick Brown, Doyle Burnett, Raven Calais, Ben Caldwell, Tomas Caspers, Roberto Castaldo, Sofia Celic-Li, Sambhavi Chandrashekar, Mike Cherim, Jonathan Chetwynd, Wendy Chisholm, Alan Chuter, David M Clark, Joe Clark, Darcy Clarke, James Coltham, Earl Cousins, James Craig, Tom Croucher, Pierce Crowell, Nir Dagan, Daniel Dardailler, Geoff Deering, Sébastien Delorme, Pete DeVasto, Iyad Abu Doush, Sylvie Duchateau, Cherie Eckholm, Roberto Ellero, Don Evans, Gavin Evans, Neal Ewers, Steve Faulkner, Bengt Farre, Lainey Feingold, Wilco Fiers, Michel Fitos, Alan J. Flavell, Nikolaos Floratos, Kentarou Fukuda, Miguel Garcia, P.J. Gardner, Alistair Garrison, Greg Gay, Becky Gibson, Al Gilman, Kerstin Goldsmith, Michael Grade, Karl Groves, Loretta Guarino Reid, Jon Gunderson, Emmanuelle Gutiérrez y Restrepo, Brian Hardy, Eric Hansen, Benjamin Hawkes-Lewis, Sean Hayes, Shawn Henry, Hans Hillen, Donovan Hipke, Bjoern Hoehrmann, Allen Hoffman, Chris Hofstader, Yvette Hoitink, Martijn Houtepen, Carlos Iglesias, Richard Ishida, Jonas Jacek, Ian Jacobs, Phill Jenkins, Barry Johnson, Duff Johnson, Jyotsna Kaki, Shilpi Kapoor, Leonard R. Kasday, Kazuhito Kidachi, Ken Kipness, Johannes Koch, Marja-Riitta Koivunen, Maureen Kraft, Preety Kumar, Kristjan Kure, Andrew LaHart, Gez Lemon, Chuck Letourneau, Aurélien Levy, Harry Loots, Scott Luebking, Tim Lacy, Jim Ley, Alex Li, William Loughborough, N Maffeo, Mark Magennis, Erich Manser, Kapsi Maria, Luca Mascaro, Matt May, Sheena McCullagh, Liam McGee, Jens Oliver Meiert, Niqui Merret, Jonathan Metz, Alessandro Miele, Steven Miller, Mathew J Mirabella, Matt May, Marti McCuller, Sorcha Moore, Charles F. Munat, Robert Neff, Charles Nevile, Liddy Nevile, Dylan Nicholson, Bruno von Niman, Tim Noonan, Sebastiano Nutarelli, Graham Oliver, Sean B. Palmer, Charu Pandhi, evarshi Pant, Nigel Peck, Anne Pemberton, David Poehlman, Ian Pouncey, Charles Pritchard, Kerstin Probiesch, W Reagan, Adam Victor Reed, Chris Reeve, Chris Ridpath, Lee Roberts, Mark Rogers, Raph de Rooij, Gregory J. Rosmaita, Matthew Ross, Sharron Rush, Joel Sanda, Janina Sajka, Roberto Scano, Gordon Schantz, Tim van Schie, Wolf Schmidt, Stefan Schnabel, Cynthia Shelly, Glenda Sims, John Slatin, Becky Smith, Jared Smith, Andi Snow-Weaver, Neil Soiffer, Mike Squillace, Michael Stenitzer, Diane Stottlemyer, Christophe Strobbe, Sarah J Swierenga, Jim Thatcher, Terry Thompson, Justin Thorp, David Todd, Mary Utt, Jean Vanderdonckt, Carlos A Velasco, Eric Velleman, Gijs Veyfeyken, Dena Wainwright, Paul Walsch, Daman Wandke, Richard Warren, Elle Waters, Takayuki Watanabe, Gian Wild, David Wooley, Wu Wei, Kenny Zhang, Leona Zumbo.

### B.3 Enabling funders

This publication has been funded in part with U.S. Federal funds from the Health and Human Services, National Institute on Disability, Independent Living, and Rehabilitation Research \(NIDILRR\), initially under contract number ED-OSE-10-C-0067, then under contract number HHSP23301500054C, and now under HHS75P00120P00168. The content of this publication does not necessarily reflect the views or policies of the U.S. Department of Health and Human Services or the U.S. Department of Education, nor does mention of trade names, commercial products, or organizations imply endorsement by the U.S. Government.

## C. References

### C.1 Informative references

\[css3-values\] CSS Values and Units Module Level 3 . Tab Atkins Jr.; Elika Etemad. W3C. 22 March 2024. W3C Candidate Recommendation. URL: https://www.w3.org/TR/css-values-3/ \[HTML\] HTML Standard . Anne van Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL: https://html.spec.whatwg.org/multipage/ \[ISO\_9241-391\] Ergonomics of human-system interaction—Part 391: Requirements, analysis and compliance test methods for the reduction of photosensitive seizures . International Standards Organization. URL: https://www.iso.org/standard/56350.html \[pointerevents\] Pointer Events . Jacob Rossi; Matt Brubeck. W3C. 4 April 2019. W3C Recommendation. URL: https://www.w3.org/TR/pointerevents/ \[RFC2119\] Key words for use in RFCs to Indicate Requirement Levels . S. Bradner. IETF. March 1997. Best Current Practice. URL: https://www.rfc-editor.org/rfc/rfc2119 \[SRGB\] Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB . IEC. URL: https://webstore.iec.ch/publication/6169 \[UAAG10\] User Agent Accessibility Guidelines 1.0 . Ian Jacobs; Jon Gunderson; Eric Hansen. W3C. 17 December 2002. W3C Recommendation. URL: https://www.w3.org/TR/UAAG10/ \[UNESCO\] International Standard Classification of Education . 2011. URL: https://unesdoc.unesco.org/ark:/48223/pf0000219109 \[WAI-WEBCONTENT\] Web Content Accessibility Guidelines 1.0 . Wendy Chisholm; Gregg Vanderheiden; Ian Jacobs. W3C. 5 May 1999. W3C Recommendation. URL: https://www.w3.org/TR/WAI-WEBCONTENT/ \[WCAG20\] Web Content Accessibility Guidelines \(WCAG\) 2.0 . Ben Caldwell; Michael Cooper; Loretta Guarino Reid; Gregg Vanderheiden et al. W3C. 11 December 2008. W3C Recommendation. URL: https://www.w3.org/TR/WCAG20/ \[WCAG21\] Web Content Accessibility Guidelines \(WCAG\) 2.1 . Michael Cooper; Andrew Kirkpatrick; Joshue O'Connor; Alastair Campbell. W3C. 21 September 2023. W3C Recommendation. URL: https://www.w3.org/TR/WCAG21/
