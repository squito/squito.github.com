---
layout: default
title: "imran"
---

<div class="about">
  <h1>WELCOME</h1>
  <p>
    I am a Software Developer with expertise in data analysis, with focus on algorithms and data mining. Extensive experience analyzing large scale data sets in a distributed computing environment.
  </p>
  <div class="divide">
  {% include ornaments.html %}
  </div>
</div>

<div class="content">
  <div class="posts">
      <ul>
      {% for post in site.posts %}
          <li>
          <span>{{ post.date | date: "%B %e, %Y" }}</span><a href="{{ post.url }}">{{ post.title }}</a>
          </li>
      {% endfor %}
      </ul>
  </div>
</div>
